<#
.SYNOPSIS
    Main orchestration logic for syncing ArchiveGUIDs.

.DESCRIPTION
    Coordinates the entire sync process:
    1. Establishes connections to EXO, on-premises Exchange, and AD
    2. Retrieves all mailboxes from both environments
    3. Iterates through EXO mailboxes with archives
    4. Matches to on-premises mailboxes
    5. Syncs ArchiveGUID to both AD and on-premises Exchange
    6. Builds results array for reporting

    Uses continue-on-error strategy: failures are logged but do not stop processing.

.PARAMETER ExchangeServer
    FQDN of the on-premises Exchange server

.PARAMETER OutputPath
    Path where the sync report CSV will be saved

.PARAMETER WhatIf
    If specified, performs all operations in read-only mode (no actual writes)

.OUTPUTS
    [PSCustomObject] Array of sync results ready for reporting

.EXAMPLE
    $Results = Invoke-ArchiveGuidSync -ExchangeServer 'exchange.corp.com' -OutputPath '.\report.csv'
#>
function Invoke-ArchiveGuidSync {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $ExchangeServer,

        [Parameter(Mandatory = $true)]
        [string]
        $OutputPath,

        [switch]
        $WhatIf
    )

    $Results = @()
    $ExchangeSession = $null
    $ErrorCount = 0
    $SkipCount = 0
    $SuccessCount = 0

    try {
        # Step 1: Connect to services
        Write-Verbose -Message "=== Starting ArchiveGUID Sync Process ==="
        Write-Verbose -Message "Step 1: Establishing connections..."

        Connect-EXOSession | Out-Null
        Write-Verbose -Message "Connected to Exchange Online"

        $ExchangeSession = Connect-OnPremExchangeSession -ExchangeServer $ExchangeServer
        Write-Verbose -Message "Connected to on-premises Exchange: $ExchangeServer"

        Connect-ADSession | Out-Null
        Write-Verbose -Message "Connected to on-premises Active Directory"

        # Step 2: Retrieve mailboxes
        Write-Verbose -Message "Step 2: Retrieving mailboxes from both environments..."

        $ExoMailboxes = Get-EXOMailboxesWithArchive
        $OnPremMailboxes = Get-OnPremMailboxes -ExchangeSession $ExchangeSession

        $ExoCount = @($ExoMailboxes).Count
        $OnPremCount = @($OnPremMailboxes).Count
        Write-Verbose -Message "Retrieved $ExoCount EXO mailboxes with archives"
        Write-Verbose -Message "Retrieved $OnPremCount on-premises mailboxes"

        # Step 3: Sync loop
        Write-Verbose -Message "Step 3: Processing EXO mailboxes for sync..."
        $ProcessingIndex = 0

        foreach ($ExoMailbox in $ExoMailboxes) {
            $ProcessingIndex++
            $CurrentOperation = "[$ProcessingIndex/$ExoCount] $($ExoMailbox.UserPrincipalName)"
            Write-Verbose -Message "Processing: $CurrentOperation"

            try {
                # Match to on-premises mailbox
                $OnPremMailbox = Match-OnPremMailbox -ExoMailbox $ExoMailbox -OnPremMailboxes $OnPremMailboxes

                if (-not $OnPremMailbox) {
                    Write-Verbose -Message "SKIPPED: No matching on-premises mailbox for $($ExoMailbox.UserPrincipalName)"
                    $Results += [PSCustomObject]@{
                        Mailbox   = $ExoMailbox.UserPrincipalName
                        Status    = 'Skipped'
                        Message   = 'No matching on-premises mailbox found'
                        Timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
                    }
                    $SkipCount++
                    continue
                }

                # Perform sync (or WhatIf)
                if ($WhatIf) {
                    Write-Verbose -Message "WHATIF: Would sync ArchiveGUID $($ExoMailbox.ArchiveGuid) to $($OnPremMailbox.SamAccountName)"
                    $Results += [PSCustomObject]@{
                        Mailbox   = $ExoMailbox.UserPrincipalName
                        Status    = 'Success (WhatIf)'
                        Message   = "Would sync ArchiveGUID: $($ExoMailbox.ArchiveGuid)"
                        Timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
                    }
                    $SuccessCount++
                }
                else {
                    $SyncResult = Sync-ArchiveGuidToOnPrem -OnPremMailbox $OnPremMailbox -ArchiveGUID $ExoMailbox.ArchiveGuid -ExchangeSession $ExchangeSession

                    $Results += [PSCustomObject]@{
                        Mailbox   = $ExoMailbox.UserPrincipalName
                        Status    = if ($SyncResult.Success) { 'Success' } else { 'Failed' }
                        Message   = $SyncResult.Message
                        Timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
                    }

                    if ($SyncResult.Success) {
                        Write-Verbose -Message "SUCCESS: Synced ArchiveGUID for $($ExoMailbox.UserPrincipalName)"
                        $SuccessCount++
                    }
                    else {
                        Write-Verbose -Message "FAILED: Could not sync ArchiveGUID for $($ExoMailbox.UserPrincipalName)"
                        $ErrorCount++
                    }
                }
            }
            catch {
                Write-Verbose -Message "ERROR processing $CurrentOperation : $_"
                $Results += [PSCustomObject]@{
                    Mailbox   = $ExoMailbox.UserPrincipalName
                    Status    = 'Failed'
                    Message   = "Unexpected error: $_"
                    Timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
                }
                $ErrorCount++
            }
        }

        # Step 4: Generate report
        Write-Verbose -Message "Step 4: Generating report..."
        Write-SyncReport -Results $Results -OutputPath $OutputPath

        # Print summary
        Write-Verbose -Message ""
        Write-Verbose -Message "=== Sync Complete ==="
        Write-Verbose -Message "Total mailboxes processed: $ExoCount"
        Write-Verbose -Message "Successful syncs: $SuccessCount"
        Write-Verbose -Message "Failed syncs: $ErrorCount"
        Write-Verbose -Message "Skipped: $SkipCount"
        Write-Verbose -Message "Report saved to: $OutputPath"

        return $Results
    }
    catch {
        Write-Warning -Message "Fatal error during sync process: $_"
        throw
    }
    finally {
        if ($ExchangeSession) {
            Write-Verbose -Message "Closing on-premises Exchange session..."
            Remove-PSSession -Session $ExchangeSession -ErrorAction SilentlyContinue | Out-Null
        }

        Write-Verbose -Message "Disconnecting from Exchange Online..."
        try {
            Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        }
        catch {
            # Ignore disconnect errors
        }
    }
}
