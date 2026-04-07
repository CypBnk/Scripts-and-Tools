<#
.SYNOPSIS
    Syncs ArchiveGUID from Exchange Online to on-premises Active Directory and Exchange.

.DESCRIPTION
    Synchronizes ArchiveGUID values from all Exchange Online mailboxes (that have archives enabled)
    to their corresponding on-premises mailboxes in both Active Directory and on-premises Exchange Server.

    The script matches mailboxes by SAM/UPN first, retrieves ArchiveGUIDs from EXO,
    and writes them to both on-premises AD and Exchange for each matched mailbox.

.PARAMETER OnPremExchangeServer
    Mandatory. FQDN of the on-premises Exchange Server to connect to.
    Example: 'exchange.contoso.com' or 'exch01.corp.local'

.PARAMETER OutputPath
    Optional. Path where the sync report CSV will be saved.
    Default: .\ArchiveGuidSync_YYYYMMdd_HHmmss.csv in the current directory

.PARAMETER WhatIf
    Shows what would be synced without making actual changes.

.PARAMETER Verbose
    Displays detailed output about connections and sync progress.

.OUTPUTS
    None. Results are written to the report CSV file and console.

.EXAMPLE
    Sync-ArchiveGuidFromEXO -OnPremExchangeServer 'exchange.contoso.com'

.EXAMPLE
    Sync-ArchiveGuidFromEXO -OnPremExchangeServer 'exchange.contoso.com' -WhatIf -Verbose

.NOTES
    Requires Exchange Online Management Module and Active Directory module (RSAT).
#>
function Sync-ArchiveGuidFromEXO {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $OnPremExchangeServer,

        [Parameter(Mandatory = $false)]
        [string]
        $OutputPath = ""
    )

    begin {
        # Generate default output path if not provided
        if ([string]::IsNullOrWhiteSpace($OutputPath)) {
            $Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
            $OutputPath = Join-Path -Path (Get-Location) -ChildPath "ArchiveGuidSync_$Timestamp.csv"
        }

        Write-Verbose -Message "Sync-ArchiveGuidFromEXO starting..."
        Write-Verbose -Message "On-Premises Exchange Server: $OnPremExchangeServer"
        Write-Verbose -Message "Output Path: $OutputPath"
        if ($WhatIfPreference) {
            Write-Verbose -Message "WhatIf mode: No changes will be made"
        }
    }

    process {
        try {
            # Validate on-premises server is reachable before proceeding
            Write-Host "Validating on-premises Exchange server connectivity..."
            $TestConnection = Test-NetConnection -ComputerName $OnPremExchangeServer -Port 5985 -WarningAction SilentlyContinue -InformationAction SilentlyContinue
            if (-not $TestConnection.TcpTestSucceeded) {
                throw "Cannot reach Exchange server $OnPremExchangeServer on port 5985 (WinRM). Verify FQDN and network connectivity."
            }
            Write-Host "[OK] Server connectivity verified"

            # Confirm action if not SilentlyContinue
            if ($PSCmdlet.ShouldProcess("ArchiveGUID sync from EXO to $OnPremExchangeServer", "Execute")) {
                Write-Host "Starting ArchiveGUID synchronization..." -ForegroundColor Cyan

                # Call orchestration function
                $Results = Invoke-ArchiveGuidSync -ExchangeServer $OnPremExchangeServer `
                    -OutputPath $OutputPath `
                    -WhatIf:$WhatIfPreference `
                    -Verbose:$VerbosePreference

                Write-Host "[OK] Sync completed successfully" -ForegroundColor Green
                return $Results
            }
            else {
                Write-Host "Sync cancelled by user" -ForegroundColor Yellow
                return $null
            }
        }
        catch {
            Write-Error -Message "ArchiveGUID sync failed: $_"
            throw
        }
    }

    end {
        Write-Verbose -Message "Sync-ArchiveGuidFromEXO completed"
    }
}
