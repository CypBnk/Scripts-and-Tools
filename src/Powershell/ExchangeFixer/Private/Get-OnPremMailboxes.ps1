<#
.SYNOPSIS
    Retrieves all mailboxes from on-premises Exchange Server.

.DESCRIPTION
    Uses a remote session to query on-premises Exchange for all mailboxes.
    Returns structured objects with mailbox properties needed for matching and writing archive GUIDs.

.PARAMETER ExchangeSession
    Remote PSSession connected to on-premises Exchange Server.

.OUTPUTS
    [PSCustomObject[]] Array of mailboxes with properties: DisplayName, SamAccountName,
    PrimarySmtpAddress, Identity, DistinguishedName

.EXAMPLE
    $OnPremMailboxes = Get-OnPremMailboxes -ExchangeSession $Session
    # Returns all on-premises mailboxes
#>
function Get-OnPremMailboxes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.Runspaces.PSSession]
        $ExchangeSession
    )

    try {
        Write-Verbose -Message "Retrieving all on-premises mailboxes..."

        $Mailboxes = Invoke-Command -Session $ExchangeSession -ScriptBlock {
            Get-Mailbox -ResultSize Unlimited -ErrorAction Stop | 
            Select-Object -Property @(
                'DisplayName',
                'SamAccountName',
                'PrimarySmtpAddress',
                'Identity',
                'DistinguishedName'
            )
        } -ErrorAction Stop

        $Count = @($Mailboxes).Count
        Write-Verbose -Message "Retrieved $Count on-premises mailboxes"

        return $Mailboxes
    }
    catch {
        throw "Failed to retrieve on-premises mailboxes: $_"
    }
}
