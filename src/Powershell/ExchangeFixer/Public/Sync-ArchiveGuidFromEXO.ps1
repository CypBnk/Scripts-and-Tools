<#
.SYNOPSIS
    Syncs ArchiveGUID from Exchange Online to on-premises Active Directory and Exchange.

.DESCRIPTION
    Synchronizes ArchiveGUID values from all Exchange Online mailboxes (that have archives enabled)
    to their corresponding on-premises mailboxes in both Active Directory and on-premises Exchange Server.

    The script matches mailboxes by SAM/UPN first, retrieves ArchiveGUIDs from EXO,
    and writes them to both on-premises AD and Exchange for each matched mailbox.

    When invoked without parameters, displays an interactive menu to choose between full sync
    and single-user test mode.

.PARAMETER OnPremExchangeServer
    Optional. FQDN or NetBIOS name of the on-premises Exchange Server to connect to.
    Example: 'exchange.contoso.com' or 'exch01'
    If omitted, displays interactive menu.

.PARAMETER ADDomainController
    Optional. FQDN of specific domain controller to use for AD operations.
    If not specified but ADDomain is provided, discovers DC in that domain.
    If neither specified, auto-discovers the PDC emulator of the current domain.
    Example: 'dc1.contoso.com'

.PARAMETER ADDomain
    Optional. Active Directory domain name for DC discovery (fallback if DomainController not specified).
    Useful when connecting to different domain than current machine domain.
    Example: 'contoso.com'

.PARAMETER VanityDomain
    Optional. Vanity/corporate domain for matching on-premises mailboxes to EXO mailboxes.
    When EXO UPN is user@onmicrosoft.com, searches on-premises for user@vanitydomain.com as fallback.
    Useful for hybrid environments with onmicrosoft.com UPNs and on-premises vanity domains.
    Example: 'contoso.com'

.PARAMETER TestUser
    Optional. SAM account name or UPN of a single user to validate in end-to-end test mode.
    When specified, performs full sync pipeline (EXO→AD→on-prem) for only that user.
    Results displayed to console; no CSV report generated.
    Example: -TestUser 'jsmith' or -TestUser 'jsmith@contoso.com'

.PARAMETER OutputPath
    Optional. Path where the sync report CSV will be saved (ignored in test mode).
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
    None. Results are written to the report CSV file (full sync) or console (test mode).

.EXAMPLE
    Sync-ArchiveGuidFromEXO
    # Displays interactive menu for options

.EXAMPLE
    Sync-ArchiveGuidFromEXO -OnPremExchangeServer 'exchange.contoso.com'
    # Full sync with current user credentials and auto-discovered domain controller

.EXAMPLE
    Sync-ArchiveGuidFromEXO -OnPremExchangeServer 'exchange.contoso.com' -ADDomainController 'dc1.contoso.com' -Verbose
    # Full sync using specific domain controller with verbose output

.EXAMPLE
    Sync-ArchiveGuidFromEXO -OnPremExchangeServer 'exchange.contoso.com' -ADDomain 'contoso.com' -Verbose
    # Full sync using domain name for DC discovery (fallback option)

.EXAMPLE
    Sync-ArchiveGuidFromEXO -OnPremExchangeServer 'exchange.contoso.com' -VanityDomain 'contoso.com' -Verbose
    # Full sync with vanity domain UPN matching for onmicrosoft.com UPNs

.EXAMPLE
    Sync-ArchiveGuidFromEXO -OnPremExchangeServer 'exchange.contoso.com' -TestUser 'user@contoso.onmicrosoft.com' -VanityDomain 'contoso.com' -Verbose
    # Test user with vanity domain fallback: searches for user@contoso.com on-premises

.EXAMPLE
    Sync-ArchiveGuidFromEXO -OnPremExchangeServer 'exchange.contoso.com' -TestUser 'jsmith' -Verbose
    # End-to-end validation for single user with console output

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
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $OnPremExchangeServer = "",

        [Parameter(Mandatory = $false)]
        [string]
        $ADDomainController = $null,

        [Parameter(Mandatory = $false)]
        [string]
        $ADDomain = $null,

        [Parameter(Mandatory = $false)]
        [string]
        $VanityDomain = $null,

        [Parameter(Mandatory = $false)]
        [string]
        $TestUser = $null,

        [Parameter(Mandatory = $false)]
        [string]
        $OutputPath = "",

        [Parameter(Mandatory = $false)]
        [PSCredential]
        $Credential
    )

    begin {
        # Resolve domain controller if not specified
        if ([string]::IsNullOrWhiteSpace($ADDomainController)) {
            $ADDomainController = $script:DefaultDomainController
            if ($ADDomainController) {
                Write-Verbose -Message "Using discovered domain controller: $ADDomainController"
            }
        }
        else {
            Write-Verbose -Message "Using specified domain controller: $ADDomainController"
        }

        # Generate default output path if not provided
        if ([string]::IsNullOrWhiteSpace($OutputPath)) {
            $Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
            $OutputPath = Join-Path -Path (Get-Location) -ChildPath "ArchiveGuidSync_$Timestamp.csv"
        }

        Write-Verbose -Message "Sync-ArchiveGuidFromEXO starting..."
        if ($TestUser) {
            Write-Verbose -Message "Test Mode: Single user validation for: $TestUser"
        }
        Write-Verbose -Message "On-Premises Exchange Server: $OnPremExchangeServer"
        Write-Verbose -Message "Domain Controller: $ADDomainController"
        if ($ADDomain) {
            Write-Verbose -Message "Domain Fallback: $ADDomain"
        }
        if ($VanityDomain) {
            Write-Verbose -Message "Vanity Domain for Matching: $VanityDomain"
        }
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
            # Show interactive menu if no parameters provided
            if ([string]::IsNullOrWhiteSpace($OnPremExchangeServer)) {
                Write-Host "`n=== ArchiveGUID Synchronization Menu ===" -ForegroundColor Cyan
                Write-Host "1. Full synchronization (all EXO mailboxes with archives)" -ForegroundColor Gray
                Write-Host "2. Test single user (end-to-end validation)" -ForegroundColor Gray
                Write-Host "3. Exit" -ForegroundColor Gray
                $MenuChoice = Read-Host "`nSelect option (1-3)"

                switch ($MenuChoice) {
                    "1" {
                        $OnPremExchangeServer = Read-Host "Enter on-premises Exchange server FQDN"
                        if ([string]::IsNullOrWhiteSpace($OnPremExchangeServer)) {
                            throw "Exchange server name cannot be empty"
                        }
                        $InputDC = Read-Host "Enter domain controller FQDN (press Enter for auto-discovery)"
                        if (-not [string]::IsNullOrWhiteSpace($InputDC)) {
                            $ADDomainController = $InputDC
                        }
                        else {
                            $InputDomain = Read-Host "Enter domain name for DC discovery, e.g., contoso.com (press Enter to skip)"
                            if (-not [string]::IsNullOrWhiteSpace($InputDomain)) {
                                $ADDomain = $InputDomain
                            }
                        }
                        $InputVanity = Read-Host "Enter vanity domain for UPN matching, e.g., contoso.com (press Enter to skip)"
                        if (-not [string]::IsNullOrWhiteSpace($InputVanity)) {
                            $VanityDomain = $InputVanity
                        }
                        Write-Verbose -Message "Menu selection: Full sync mode"
                    }
                    "2" {
                        $OnPremExchangeServer = Read-Host "Enter on-premises Exchange server FQDN"
                        if ([string]::IsNullOrWhiteSpace($OnPremExchangeServer)) {
                            throw "Exchange server name cannot be empty"
                        }
                        $TestUser = Read-Host "Enter username to test (SAM or UPN)"
                        if ([string]::IsNullOrWhiteSpace($TestUser)) {
                            throw "Username cannot be empty"
                        }
                        $InputDC = Read-Host "Enter domain controller FQDN (press Enter for auto-discovery)"
                        if (-not [string]::IsNullOrWhiteSpace($InputDC)) {
                            $ADDomainController = $InputDC
                        }
                        else {
                            $InputDomain = Read-Host "Enter domain name for DC discovery, e.g., contoso.com (press Enter to skip)"
                            if (-not [string]::IsNullOrWhiteSpace($InputDomain)) {
                                $ADDomain = $InputDomain
                            }
                        }
                        $InputVanity = Read-Host "Enter vanity domain for UPN matching, e.g., contoso.com (press Enter to skip)"
                        if (-not [string]::IsNullOrWhiteSpace($InputVanity)) {
                            $VanityDomain = $InputVanity
                        }
                        Write-Verbose -Message "Menu selection: Single user test mode for user: $TestUser"
                    }
                    "3" {
                        Write-Host "Exiting..." -ForegroundColor Yellow
                        return $null
                    }
                    default {
                        throw "Invalid selection. Please choose 1, 2, or 3."
                    }
                }
                Write-Host ""
            }

            # Use cached prerequisite check result (tested only on module import)
            Write-Host "`nUsing cached prerequisite check from module load..." -ForegroundColor Yellow
            if (-not $script:PrereqCheckCached) {
                Write-Host "`nWarning: Some prerequisites are missing. The sync may fail. Install missing components:" -ForegroundColor Yellow
                Write-Host "  - ActiveDirectory module: Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0" -ForegroundColor Gray
                Write-Host "  - Enable-PSRemoting: Run 'Enable-PSRemoting -Force' with administrator privileges" -ForegroundColor Gray
                $Confirmation = Read-Host "Continue anyway? (Y/N)"
                if ($Confirmation -ne 'Y' -and $Confirmation -ne 'y') {
                    Write-Host "Sync cancelled by user" -ForegroundColor Yellow
                    return $null
                }
            }
            else {
                Write-Host "[OK] Prerequisites cached from module load" -ForegroundColor Green
            }

            # Validate on-premises server is reachable before proceeding
            Write-Host "`nValidating on-premises Exchange server connectivity..." -ForegroundColor Yellow
            $TestConnection = Test-NetConnection -ComputerName $OnPremExchangeServer -Port 5985 -WarningAction SilentlyContinue -InformationAction SilentlyContinue
            if (-not $TestConnection.TcpTestSucceeded) {
                throw "Cannot reach Exchange server $OnPremExchangeServer on port 5985 (WinRM). Verify FQDN and network connectivity."
            }
            Write-Host "[OK] Server connectivity verified" -ForegroundColor Green

            # Confirm action if not SilentlyContinue
            $OperationType = if ($TestUser) { "single user test for $TestUser" } else { "full ArchiveGUID sync" }
            if ($PSCmdlet.ShouldProcess("$OperationType on $OnPremExchangeServer", "Execute")) {
                Write-Host "`nStarting ArchiveGUID synchronization..." -ForegroundColor Cyan

                # Call orchestration function with credential if provided
                $InvokeParams = @{
                    ExchangeServer     = $OnPremExchangeServer
                    OutputPath         = $OutputPath
                    ADDomainController = $ADDomainController
                    WhatIf             = $WhatIfPreference
                    Verbose            = $VerbosePreference
                }                
                if ($ADDomain) {
                    $InvokeParams['ADDomain'] = $ADDomain
                }
                if ($PSBoundParameters.ContainsKey('Credential')) {
                    $InvokeParams['Credential'] = $Credential
                }

                if ($TestUser) {
                    $InvokeParams['TestUser'] = $TestUser
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
