<#
.SYNOPSIS
    Syncs ArchiveGUID from Exchange Online to on-premises Active Directory and Exchange.

.DESCRIPTION
    Synchronizes ArchiveGUID values from all Exchange Online mailboxes (that have archives enabled)
    to their corresponding on-premises mailboxes in both Active Directory and on-premises Exchange Server.

    The script matches mailboxes by SAM/UPN first, retrieves ArchiveGUIDs from EXO,
    and writes them to both on-premises AD and Exchange for each matched mailbox.

.PARAMETER OnPremExchangeServer
    Mandatory. FQDN or NetBIOS name of the on-premises Exchange Server to connect to.
    Example: 'exchange.contoso.com' or 'exch01'

.PARAMETER OutputPath
    Optional. Path where the sync report CSV will be saved.
    Default: .\ArchiveGuidSync_YYYYMMdd_HHmmss.csv in the current directory

.PARAMETER Credential
    Optional. PSCredential object for on-premises Exchange connection if current user lacks permissions.
    If not provided, uses current user's identity.
    Example: -Credential (Get-Credential)

.PARAMETER WhatIf
    Shows what would be synced without making actual changes.

.PARAMETER Verbose
    Displays detailed output about connections and sync progress.

.OUTPUTS
    None. Results are written to the report CSV file and console.

.EXAMPLE
    Sync-ArchiveGuidFromEXO -OnPremExchangeServer 'exchange.contoso.com'
    # Uses current user credentials

.EXAMPLE
    Sync-ArchiveGuidFromEXO -OnPremExchangeServer 'exchange.contoso.com' -Credential (Get-Credential) -Verbose
    # Uses specified credentials with verbose output

.EXAMPLE
    Sync-ArchiveGuidFromEXO -OnPremExchangeServer 'exchange.contoso.com' -WhatIf -Verbose
    # Preview mode: shows what would be synced without making changes

.NOTES
    Requires: 
    - Exchange Online Management Module (v2.0.5+)
    - Active Directory module (RSAT)
    - Exchange Online Administrator role
    - Exchange Server Administrator role (on-premises)
    - Active Directory Domain Administrator or equivalent
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
        $OutputPath = "",

        [Parameter(Mandatory = $false)]
        [PSCredential]
        $Credential
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
        if ($PSBoundParameters.ContainsKey('Credential')) {
            Write-Verbose -Message "Using alternative credentials for on-premises connection"
        }
        else {
            Write-Verbose -Message "Using current user identity for on-premises connection"
        }
        if ($WhatIfPreference) {
            Write-Verbose -Message "WhatIf mode: No changes will be made"
        }
    }

    process {
        try {
            # Check critical prerequisites before proceeding
            Write-Host "`nChecking critical prerequisites..." -ForegroundColor Yellow
            $PrereqPassed = Test-Prerequisites
            
            if (-not $PrereqPassed) {
                Write-Host "`nWarning: Some prerequisites are missing. The sync may fail. Install missing components:" -ForegroundColor Yellow
                Write-Host "  - ActiveDirectory module: Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0" -ForegroundColor Gray
                Write-Host "  - Enable-PSRemoting: Run 'Enable-PSRemoting -Force' with administrator privileges" -ForegroundColor Gray
                $Confirmation = Read-Host "Continue anyway? (Y/N)"
                if ($Confirmation -ne 'Y' -and $Confirmation -ne 'y') {
                    Write-Host "Sync cancelled by user" -ForegroundColor Yellow
                    return $null
                }
            }

            # Validate on-premises server is reachable before proceeding
            Write-Host "`nValidating on-premises Exchange server connectivity..." -ForegroundColor Yellow
            $TestConnection = Test-NetConnection -ComputerName $OnPremExchangeServer -Port 5985 -WarningAction SilentlyContinue -InformationAction SilentlyContinue
            if (-not $TestConnection.TcpTestSucceeded) {
                throw "Cannot reach Exchange server $OnPremExchangeServer on port 5985 (WinRM). Verify FQDN and network connectivity."
            }
            Write-Host "[OK] Server connectivity verified" -ForegroundColor Green

            # Confirm action if not SilentlyContinue
            if ($PSCmdlet.ShouldProcess("ArchiveGUID sync from EXO to $OnPremExchangeServer", "Execute")) {
                Write-Host "`nStarting ArchiveGUID synchronization..." -ForegroundColor Cyan

                # Call orchestration function with credential if provided
                $InvokeParams = @{
                    ExchangeServer = $OnPremExchangeServer
                    OutputPath     = $OutputPath
                    WhatIf         = $WhatIfPreference
                    Verbose        = $VerbosePreference
                }

                if ($PSBoundParameters.ContainsKey('Credential')) {
                    $InvokeParams['Credential'] = $Credential
                }

                $Results = Invoke-ArchiveGuidSync @InvokeParams

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
