<#
.SYNOPSIS
    Writes the ArchiveGUID to both on-premises AD and Exchange for a mailbox.

.DESCRIPTION
    Performs two write operations:
    1. Updates the AD user object with the ArchiveGUID in the msExchArchiveGUID attribute
    2. Updates the on-premises Exchange mailbox with Set-Mailbox

    Uses try/catch to handle errors gracefully and continue on partial failures.

.PARAMETER OnPremMailbox
    On-premises mailbox object to update (must have DistinguishedName and Identity)

.PARAMETER ArchiveGUID
    GUID value to write as the ArchiveGUID

.PARAMETER ExchangeSession
    Remote PSSession connected to on-premises Exchange Server

.OUTPUTS
    [PSCustomObject] With properties: Mailbox, Success, Message

.EXAMPLE
    $Result = Sync-ArchiveGuidToOnPrem -OnPremMailbox $Mbx -ArchiveGUID $guid -ExchangeSession $Session
    # Returns @{ Mailbox = 'user@corp.com'; Success = $true; Message = '...' }
#>
function Sync-ArchiveGuidToOnPrem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]
        $OnPremMailbox,

        [Parameter(Mandatory = $true)]
        [guid]
        $ArchiveGUID,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.Runspaces.PSSession]
        $ExchangeSession
    )

    $Result = @{
        Mailbox = $OnPremMailbox.SamAccountName
        Success = $false
        Message = ''
    }

    try {
        $ADUpdated = $false
        $ExchangeUpdated = $false

        # Step 1: Write to on-premises AD
        try {
            Write-Verbose -Message "Writing ArchiveGUID to AD for mailbox: $($OnPremMailbox.SamAccountName)"
            
            $ADUser = Get-ADUser -Identity $OnPremMailbox.SamAccountName -ErrorAction Stop
            Set-ADUser -Identity $ADUser -Add @{ 'msExchArchiveGUID' = $ArchiveGUID.ToByteArray() } -ErrorAction Stop
            
            Write-Verbose -Message "Successfully updated AD msExchArchiveGUID for $($OnPremMailbox.SamAccountName)"
            $ADUpdated = $true
        }
        catch {
            Write-Warning -Message "Failed to update AD for $($OnPremMailbox.SamAccountName): $_"
            $Result.Message += "AD Update Failed: $_; "
        }

        # Step 2: Write to on-premises Exchange
        try {
            Write-Verbose -Message "Writing ArchiveGUID to on-premises Exchange for: $($OnPremMailbox.Identity)"
            
            Invoke-Command -Session $ExchangeSession -ScriptBlock {
                param($Identity, $Guid)
                Set-Mailbox -Identity $Identity -ArchiveGUID $Guid -WarningAction SilentlyContinue -ErrorAction Stop
            } -ArgumentList $OnPremMailbox.Identity, $ArchiveGUID -ErrorAction Stop

            Write-Verbose -Message "Successfully updated Exchange ArchiveGUID for $($OnPremMailbox.SamAccountName)"
            $ExchangeUpdated = $true
        }
        catch {
            Write-Warning -Message "Failed to update Exchange for $($OnPremMailbox.SamAccountName): $_"
            $Result.Message += "Exchange Update Failed: $_; "
        }

        # Determine overall success
        if ($ADUpdated -or $ExchangeUpdated) {
            $Result.Success = $true
            if ($ADUpdated -and $ExchangeUpdated) {
                $Result.Message = "ArchiveGUID synced successfully: $ArchiveGUID (AD and Exchange updated)"
            }
            elseif ($ADUpdated) {
                $Result.Message = "ArchiveGUID synced partially: $ArchiveGUID (AD updated only)"
            }
            else {
                $Result.Message = "ArchiveGUID synced partially: $ArchiveGUID (Exchange updated only)"
            }
        }
        else {
            $Result.Success = $false
            $Result.Message = $Result.Message.TrimEnd('; ')
        }

        return [PSCustomObject]$Result
    }
    catch {
        $Result.Success = $false
        $Result.Message = "Unexpected error: $_"
        return [PSCustomObject]$Result
    }
}
