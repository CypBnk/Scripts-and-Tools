<#
.SYNOPSIS
    Validates all prerequisites for ExchangeFixer module.

.DESCRIPTION
    Checks for required PowerShell modules, PowerShell version, and other dependencies
    needed for the ExchangeFixer module to function properly.

.PARAMETER Verbose
    Shows detailed status for each prerequisite check.

.OUTPUTS
    [bool] $true if all prerequisites are met, $false otherwise. Detailed output via Write-Host.

.EXAMPLE
    Test-Prerequisites -Verbose
#>
function Test-Prerequisites {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Host "`n" -NoNewline
    Write-Host "=" * 70
    Write-Host "ExchangeFixer Prerequisites Check" -ForegroundColor Cyan
    Write-Host "=" * 70

    $AllChecksPassed = $true
    $CheckResults = @()

    # Check 1: PowerShell Version
    Write-Host "`n[1/4] Checking PowerShell Version..." -ForegroundColor Yellow
    $PSVersion = $PSVersionTable.PSVersion
    if ($PSVersion.Major -ge 5 -and $PSVersion.Minor -ge 1) {
        Write-Host "      [+] PowerShell $($PSVersion.Major).$($PSVersion.Minor) - OK" -ForegroundColor Green
        $CheckResults += "PowerShell: $($PSVersion.Major).$($PSVersion.Minor) [PASS]"
    }
    else {
        Write-Host "      [-] PowerShell $($PSVersion.Major).$($PSVersion.Minor) - FAILED (requires 5.1+)" -ForegroundColor Red
        $CheckResults += "PowerShell: $($PSVersion.Major).$($PSVersion.Minor) [FAILED - requires 5.1+]"
        $AllChecksPassed = $false
    }

    # Check 2: ExchangeOnlineManagement Module
    Write-Host "`n[2/4] Checking ExchangeOnlineManagement Module..." -ForegroundColor Yellow
    $EXOModule = Get-Module -Name ExchangeOnlineManagement -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
    if ($EXOModule) {
        Write-Host "      [+] ExchangeOnlineManagement v$($EXOModule.Version) installed" -ForegroundColor Green
        $CheckResults += "ExchangeOnlineManagement: v$($EXOModule.Version) [PASS]"
    }
    else {
        Write-Host "      [-] ExchangeOnlineManagement module NOT installed" -ForegroundColor Red
        Write-Host "      Install with: Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force" -ForegroundColor DarkRed
        $CheckResults += "ExchangeOnlineManagement: [FAILED - NOT INSTALLED]"
        $AllChecksPassed = $false
    }

    # Check 3: Active Directory Module
    Write-Host "`n[3/4] Checking Active Directory Module..." -ForegroundColor Yellow
    $ADModule = Get-Module -Name ActiveDirectory -ListAvailable
    if ($ADModule) {
        Write-Host "      [+] ActiveDirectory module installed (RSAT)" -ForegroundColor Green
        $CheckResults += "ActiveDirectory: [PASS - Installed]"
    }
    else {
        Write-Host "      [-] ActiveDirectory module NOT installed" -ForegroundColor Red
        Write-Host "      Install with: Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0" -ForegroundColor DarkRed
        $CheckResults += "ActiveDirectory: [FAILED - NOT INSTALLED]"
        $AllChecksPassed = $false
    }

    # Check 4: WinRM Client (implied by being on Windows, but verify remoting is enabled)
    Write-Host "`n[4/4] Checking PowerShell Remoting..." -ForegroundColor Yellow
    try {
        $LocalmachineConnection = $Null
        $LocalmachineConnection = Test-WSMan -ErrorAction Stop | Out-Null
        if ($LocalmachineConnection) {
            Write-Host "      [+] PowerShell Remoting is enabled" -ForegroundColor Green
            $CheckResults += "PowerShell Remoting: [PASS - Enabled]"
        }
    }
    catch {
        Write-Host "      [!] PowerShell Remoting may not be fully configured (will be needed for on-premises Exchange connection)" -ForegroundColor Yellow
        Write-Host "      Configure with: Enable-PSRemoting -Force (requires elevation)" -ForegroundColor Gray
        $CheckResults += "PowerShell Remoting: [WARNING - May need configuration]"
    }

    # Summary
    Write-Host "`n" -NoNewline
    Write-Host "-" * 70
    Write-Host "Summary:" -ForegroundColor Cyan
    foreach ($Result in $CheckResults) {
        if ($Result -match "\[OK\]|\[PASS\]|[+]") {
            Write-Host "  $Result" -ForegroundColor Green
        }
        elseif ($Result -match "\[FAILED\]|\[ERROR\]|\[-\]") {
            Write-Host "  $Result" -ForegroundColor Red
        }
        else {
            Write-Host "  $Result" -ForegroundColor Yellow
        }
    }
    Write-Host "-" * 70

    if ($AllChecksPassed) {
        Write-Host "`n[+] All prerequisite checks passed! Module is ready to use." -ForegroundColor Green
    }
    else {
        Write-Host "`n[-] Some prerequisites are missing. Please install the required components before using the module." -ForegroundColor Red
    }
    Write-Host "`n"

    return $AllChecksPassed
}
