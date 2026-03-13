function Test-SguPrerequisites {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [version]$MinimumGraphVersion = [version]'2.34.0',

        [Parameter(Mandatory = $false)]
        [Alias('Slient')]
        [switch]$Silent
    )

    $failures = [System.Collections.Generic.List[string]]::new()

    # In-place status line helpers.
    # · pending  →  writes the "testing" line without a newline
    # ✓ ok       →  overwrites in-place with a green checkmark
    # ✗ fail     →  overwrites in-place with a red cross (also records the failure)
    # The {0,-60} padding ensures the overwrite always clears the pending text.
    $fmtPending = '  [·] {0}...'
    $fmtOk = "`r  [✓] {0,-60}"
    $fmtFail = "`r  [✗] {0,-60}"

    if ($Silent) {
        $writePending = { param([string]$msg) }
        $writeOk = { param([string]$msg) }
        $writeFail = { param([string]$msg, [string]$detail) $failures.Add($detail) }
    }
    else {
        $writePending = { param([string]$msg) Write-Host ($fmtPending -f $msg) -NoNewline -ForegroundColor DarkGray; Start-Sleep -Seconds 1 }
        $writeOk = { param([string]$msg) Write-Host ($fmtOk -f $msg) -ForegroundColor Green }
        $writeFail = { param([string]$msg, [string]$detail) Write-Host ($fmtFail -f $msg) -ForegroundColor Red; $failures.Add($detail) }

        Write-Host ''
        Write-Host '  Prerequisites' -ForegroundColor Cyan
        Write-Host ('  ' + ([string][char]0x2500 * 50)) -ForegroundColor DarkGray
        Write-Host ''
    }

    # --- 1. PowerShell version -----------------------------------------------
    & $writePending 'PowerShell >= 7.0'
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion -lt [version]'7.0') {
        & $writeFail ('PowerShell {0}  (requires >= 7.0  →  https://aka.ms/powershell)' -f $psVersion) `
        ('PowerShell 7.0 or newer is required. Current version: {0}. Install from https://aka.ms/powershell' -f $psVersion)
    }
    else {
        & $writeOk ('PowerShell {0}' -f $psVersion)
    }

    # --- 2. Microsoft.Graph.Authentication installed -------------------------
    & $writePending 'Microsoft.Graph.Authentication installed'
    $graphAuthModules = @(Get-Module -ListAvailable -Name 'Microsoft.Graph.Authentication')
    $selectedModule = $null

    if ($graphAuthModules.Count -eq 0) {
        & $writeFail 'Microsoft.Graph.Authentication not found  (→  Install-Module Microsoft.Graph)' `
            'Microsoft Graph PowerShell SDK is not installed. Run: Install-Module Microsoft.Graph -Scope CurrentUser'
    }
    else {
        $selectedModule = $graphAuthModules | Sort-Object Version -Descending | Select-Object -First 1
        & $writeOk ('Microsoft.Graph.Authentication {0} found' -f $selectedModule.Version)

        # --- 3. Minimum version ----------------------------------------------
        & $writePending ('Version >= {0}' -f $MinimumGraphVersion)
        if ([version]$selectedModule.Version -lt $MinimumGraphVersion) {
            & $writeFail ('Version {0}  (requires >= {1}  →  Update-Module Microsoft.Graph)' -f $selectedModule.Version, $MinimumGraphVersion) `
            ('Microsoft.Graph.Authentication {0} or newer is required. Installed: {1}. Run: Update-Module Microsoft.Graph' -f $MinimumGraphVersion, $selectedModule.Version)
        }
        else {
            & $writeOk ('Version {0}  (minimum: {1})' -f $selectedModule.Version, $MinimumGraphVersion)
        }
    }

    if (-not $Silent) {
        Write-Host ''
    }
    if ($failures.Count -gt 0) {
        if ($Silent) {
            Write-Host '  [●] Prerequisites failed.' -ForegroundColor Red
        }
        else {
            Write-Host ('  {0} prerequisite(s) failed.' -f $failures.Count) -ForegroundColor Red
            Write-Host ''
        }
        throw ("Prerequisite check failed:`n  - " + ($failures -join "`n  - "))
    }

    # --- 4. Load the module --------------------------------------------------
    & $writePending ('Loading Microsoft.Graph.Authentication {0}' -f $selectedModule.Version)
    Import-Module -Name $selectedModule.Path -Force -ErrorAction Stop | Out-Null
    & $writeOk ('Microsoft.Graph.Authentication {0} loaded' -f $selectedModule.Version)

    # --- 5. Post-import command sanity ---------------------------------------
    & $writePending 'Graph commands available'
    $missingCmds = @(
        'Connect-MgGraph', 'Disconnect-MgGraph', 'Invoke-MgGraphRequest' |
        Where-Object { -not (Get-Command -Name $_ -ErrorAction SilentlyContinue) }
    )
    if ($missingCmds.Count -gt 0) {
        & $writeFail ('Missing: {0}' -f ($missingCmds -join ', ')) `
        ('Commands not available after import: {0}' -f ($missingCmds -join ', '))
    }
    else {
        & $writeOk 'Connect-MgGraph  ·  Disconnect-MgGraph  ·  Invoke-MgGraphRequest'
    }

    if (-not $Silent) {
        Write-Host ''
    }
    if ($failures.Count -gt 0) {
        if ($Silent) {
            Write-Host '  [●] Prerequisites failed.' -ForegroundColor Red
        }
        else {
            Write-Host ('  {0} prerequisite(s) failed.' -f $failures.Count) -ForegroundColor Red
            Write-Host ''
        }
        throw ("Prerequisite check failed:`n  - " + ($failures -join "`n  - "))
    }

    if ($Silent) {
        Write-Host '  [●] Prerequisites passed.' -ForegroundColor Green
    }
    else {
        Write-Host ('  ' + ([string][char]0x2500 * 50)) -ForegroundColor DarkGray
        Write-Host '  All prerequisites satisfied.' -ForegroundColor Green
        Write-Host ''
    }

    # --- 6. Platform detection (WAM is Windows-only) -------------------------
    # $IsWindows is automatic in PS7+; PSEdition -eq 'Desktop' covers PS5.1 on Windows.
    $runningOnWindows = ($PSVersionTable.PSEdition -eq 'Desktop') -or $IsWindows

    [pscustomobject]@{
        PsVersion = $psVersion
        IsWindows = $runningOnWindows
        GraphAuth = [pscustomobject]@{
            ModuleName     = $selectedModule.Name
            ModuleVersion  = [version]$selectedModule.Version
            MinimumVersion = $MinimumGraphVersion
            SupportsWam    = ($runningOnWindows -and ([version]$selectedModule.Version -ge $MinimumGraphVersion))
            SelectedPath   = $selectedModule.Path
        }
    }
}
