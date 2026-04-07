<#
.SYNOPSIS
    Generates a CSV report of sync results and prints a summary to console.

.DESCRIPTION
    Exports the results array to a CSV file for easy analysis and audit trail.
    Also prints a summary to the console with success/failure counts and list of failed mailboxes.

.PARAMETER Results
    Array of result objects from Invoke-ArchiveGuidSync

.PARAMETER OutputPath
    Path where the CSV report file will be saved

.EXAMPLE
    Write-SyncReport -Results $SyncResults -OutputPath '.\report.csv'
    # Creates report.csv and prints summary to console
#>
function Write-SyncReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]
        $Results,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $OutputPath
    )

    try {
        # Ensure output directory exists
        $OutputDirectory = Split-Path -Path $OutputPath -Parent
        if (-not (Test-Path -Path $OutputDirectory)) {
            New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
            Write-Verbose -Message "Created output directory: $OutputDirectory"
        }

        # Export to CSV
        Write-Verbose -Message "Exporting results to CSV: $OutputPath"
        $Results | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8 -Force -ErrorAction Stop

        # Calculate statistics
        $TotalProcessed = @($Results).Count
        $Successful = @($Results | Where-Object { $_.Status -eq 'Success' -or $_.Status -like 'Success*' }).Count
        $Failed = @($Results | Where-Object { $_.Status -eq 'Failed' }).Count
        $Skipped = @($Results | Where-Object { $_.Status -eq 'Skipped' }).Count

        # Print summary to console
        Write-Host ""
        Write-Host "=========================================================="
        Write-Host "                   Sync Report Summary"
        Write-Host "=========================================================="
        Write-Host "Total Processed:   $TotalProcessed"
        Write-Host "Successful:        $Successful"
        Write-Host "Failed:            $Failed"
        Write-Host "Skipped:           $Skipped"
        Write-Host ""
        Write-Host "Report file:       $OutputPath"
        Write-Host ""

        # Print detailed failure list if there are failures
        if ($Failed -gt 0) {
            Write-Host "Failed mailboxes (manual review recommended):"
            Write-Host "-------------------------------------------"
            $FailedMailboxes = $Results | Where-Object { $_.Status -eq 'Failed' }
            foreach ($Mailbox in $FailedMailboxes) {
                Write-Host "  - $($Mailbox.Mailbox)"
                Write-Host "    Error: $($Mailbox.Message)" -ForegroundColor Yellow
            }
            Write-Host ""
        }

        Write-Host "For detailed results, open: $OutputPath"
    }
    catch {
        throw "Failed to write sync report: $_"
    }
}
