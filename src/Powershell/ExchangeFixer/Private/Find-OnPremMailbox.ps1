<#
.SYNOPSIS
    Finds an Exchange Online mailbox's matching on-premises counterpart.

.DESCRIPTION
    Matches mailboxes using a priority-based strategy:
    1. First tries to match by SAM account name
    2. Then tries to match by UserPrincipalName
    3. Finally tries to match by PrimarySmtpAddress as fallback

.PARAMETER ExoMailbox
    Exchange Online mailbox object from Get-EXOMailboxesWithArchive

.PARAMETER OnPremMailboxes
    Array of on-premises mailboxes from Get-OnPremMailboxes

.OUTPUTS
    [PSCustomObject] Matched on-premises mailbox, or $null if no match found

.EXAMPLE
    $OnPremMailbox = Find-OnPremMailbox -ExoMailbox $ExoMbx -OnPremMailboxes $OnPremMbxes
    # Returns matching on-premises mailbox or $null
#>
function Find-OnPremMailbox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]
        $ExoMailbox,

        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]
        $OnPremMailboxes
    )

    try {
        # Strategy 1: Match by SAM account
        if (-not [string]::IsNullOrWhiteSpace($ExoMailbox.SamAccountName)) {
            $Match = $OnPremMailboxes | Where-Object { $_.SamAccountName -eq $ExoMailbox.SamAccountName } | Select-Object -First 1
            if ($Match) {
                Write-Verbose -Message "Matched EXO mailbox '$($ExoMailbox.UserPrincipalName)' to on-prem by SAM: $($Match.SamAccountName)"
                return $Match
            }
        }

        # Strategy 2: Match by UserPrincipalName (if available)
        if (-not [string]::IsNullOrWhiteSpace($ExoMailbox.UserPrincipalName)) {
            # Extract UPN-like parts if needed
            $UPN = $ExoMailbox.UserPrincipalName
            $Match = $OnPremMailboxes | Where-Object { $_.PrimarySmtpAddress -like "*$($UPN.Split('@')[0])*" } | Select-Object -First 1
            if ($Match) {
                Write-Verbose -Message "Matched EXO mailbox '$($ExoMailbox.UserPrincipalName)' to on-prem by UPN pattern: $($Match.SamAccountName)"
                return $Match
            }
        }

        # Strategy 3: Match by PrimarySmtpAddress as fallback
        if (-not [string]::IsNullOrWhiteSpace($ExoMailbox.PrimarySmtpAddress)) {
            $Match = $OnPremMailboxes | Where-Object { $_.PrimarySmtpAddress -eq $ExoMailbox.PrimarySmtpAddress } | Select-Object -First 1
            if ($Match) {
                Write-Verbose -Message "Matched EXO mailbox '$($ExoMailbox.UserPrincipalName)' to on-prem by SMTP: $($Match.SamAccountName)"
                return $Match
            }
        }

        # No match found
        Write-Verbose -Message "No matching on-premises mailbox found for EXO mailbox: $($ExoMailbox.UserPrincipalName)"
        return $null
    }
    catch {
        Write-Warning -Message "Error matching EXO mailbox to on-premises: $_"
        return $null
    }
}
