<#
.SYNOPSIS
    Retrieves all Exchange Online mailboxes that have an archive enabled.

.DESCRIPTION
    Queries Exchange Online for all mailboxes where ArchiveGuid is set (i.e., archive is enabled).
    Returns structured objects with mailbox properties needed for matching and syncing.

.OUTPUTS
    [PSCustomObject[]] Array of mailboxes with properties: UserPrincipalName, SamAccountName, 
    PrimarySmtpAddress, ArchiveGUID

.EXAMPLE
    $ExoMailboxes = Get-EXOMailboxesWithArchive
    # Returns all EXO mailboxes with archives
#>
function Get-EXOMailboxesWithArchive {
    [CmdletBinding()]
    param()

    try {
        Write-Verbose -Message "Retrieving all Exchange Online mailboxes with archives..."
        
        $Mailboxes = Get-Mailbox -ResultSize Unlimited -ErrorAction Stop | 
        Where-Object { $_.ArchiveGuid -ne [guid]::Empty } |
        Select-Object -Property @(
            'DisplayName',
            'UserPrincipalName',
            'SamAccountName',
            'PrimarySmtpAddress',
            'ArchiveGuid'
        )

        $Count = @($Mailboxes).Count
        Write-Verbose -Message "Found $Count Exchange Online mailboxes with active archives"

        return $Mailboxes
    }
    catch {
        throw "Failed to retrieve Exchange Online mailboxes: $_"
    }
}
