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

.PARAMETER VanityDomain
    Optional. Vanity/corporate domain to use as fallback when matching EXO mailboxes.
    If EXO UPN is user@onmicrosoft.com, also tries user@vanitydomain.com for matching.
    Example: 'contoso.com'

.OUTPUTS
    [PSCustomObject] Matched on-premises mailbox, or $null if no match found

.EXAMPLE
    $OnPremMailbox = Find-OnPremMailbox -ExoMailbox $ExoMbx -OnPremMailboxes $OnPremMbxes
    # Returns matching on-premises mailbox or $null

.EXAMPLE
    $OnPremMailbox = Find-OnPremMailbox -ExoMailbox $ExoMbx -OnPremMailboxes $OnPremMbxes -VanityDomain 'contoso.com'
    # Tries exact match first, then tries user@contoso.com if EXO UPN is user@onmicrosoft.com
#>
function Find-OnPremMailbox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]
        $ExoMailbox,

        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]
        $OnPremMailboxes,

        [Parameter(Mandatory = $false)]
        [string]
        $VanityDomain = $null
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
            $UPN = $ExoMailbox.UserPrincipalName
            $UPNPrefix = $UPN.Split('@')[0]
            
            # Try exact UPN match first
            $Match = $OnPremMailboxes | Where-Object { $_.UserPrincipalName -eq $UPN } | Select-Object -First 1
            if ($Match) {
                Write-Verbose -Message "Matched EXO mailbox '$UPN' to on-prem by exact UPN: $($Match.SamAccountName)"
                return $Match
            }
            
            # Try vanity domain UPN if provided (for onmicrosoft.com fallback)
            if (-not [string]::IsNullOrWhiteSpace($VanityDomain)) {
                $VanityUPN = "$UPNPrefix@$VanityDomain"
                $Match = $OnPremMailboxes | Where-Object { $_.UserPrincipalName -eq $VanityUPN } | Select-Object -First 1
                if ($Match) {
                    Write-Verbose -Message "Matched EXO mailbox '$UPN' to on-prem by vanity UPN '$VanityUPN': $($Match.SamAccountName)"
                    return $Match
                }
            }
            
            # Fallback: Match by UPN pattern
            $Match = $OnPremMailboxes | Where-Object { $_.PrimarySmtpAddress -like "*$UPNPrefix*" } | Select-Object -First 1
            if ($Match) {
                Write-Verbose -Message "Matched EXO mailbox '$UPN' to on-prem by UPN pattern: $($Match.SamAccountName)"
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
