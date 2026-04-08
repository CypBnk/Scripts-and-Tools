#Requires -Version 5.1
<#
.SYNOPSIS
Interactive Entra device cleanup utility.

.DESCRIPTION
Step-by-step guided workflow to list, filter and optionally delete stale
Entra devices while protecting Autopilot-registered devices.

  Step 0  Authentication  - WAM, UPN hint or App Registration
  Step 1  List devices    - All Entra devices with activity, owner, OS, trust type
  Step 2  Filter          - Narrow down to 30 / 90 / 365 day threshold
  Step 3  Delete          - Remove non-Autopilot stale devices (read+write only)

All actions are logged to: %TEMP%\Magentascripts\YYYY-MM-DD-HH-mm-ss_Step<N>.log

.EXAMPLE
.\Invoke-EntraDeviceCleanup.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ─── Logging ──────────────────────────────────────────────────────────────────

$script:SessionTs = Get-Date -Format 'yyyy-MM-dd-HH-mm-ss'
$script:LogDir = Join-Path $env:TEMP 'Magentascripts'

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $true)]
        [string]$Step,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $null = [System.IO.Directory]::CreateDirectory($script:LogDir)
    $logFile = Join-Path $script:LogDir ('{0}_Step{1}.log' -f $script:SessionTs, $Step)
    $entry = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -Path $logFile -Value $entry -Encoding UTF8

    switch ($Level) {
        'WARN' { Write-Host ('  [WARN]  {0}' -f $Message) -ForegroundColor Yellow }
        'ERROR' { Write-Host ('  [ERROR] {0}' -f $Message) -ForegroundColor Red }
    }
}

function Write-LogCsv {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Rows,

        [Parameter(Mandatory = $true)]
        [string]$Step
    )

    if ($null -eq $Rows -or $Rows.Count -eq 0) { return }
    $null = [System.IO.Directory]::CreateDirectory($script:LogDir)
    $logFile = Join-Path $script:LogDir ('{0}_Step{1}.log' -f $script:SessionTs, $Step)
    $Rows | ConvertTo-Csv -NoTypeInformation | Add-Content -Path $logFile -Encoding UTF8
}

# ─── UI helpers ───────────────────────────────────────────────────────────────

function Show-Banner {
    Clear-Host
    Write-Host ('=' * 70) -ForegroundColor Magenta
    Write-Host '  Entra Device Cleanup Utility  |  Powered by Microsoft Graph  v1.0' -ForegroundColor Cyan
    Write-Host ('=' * 70) -ForegroundColor Magenta
    Write-Host ''
}

function Show-StepOverview {
    param([int]$PermLevel)

    Write-Host '  Steps in this session:' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  Step 0  Authentication     [Read-Only / Read+Write]' -ForegroundColor White
    Write-Host '  Step 1  List devices       [Read-Only]              — Query all Entra devices' -ForegroundColor White
    Write-Host '  Step 2  Filter             [Read-Only]              — Apply staleness threshold' -ForegroundColor White

    if ($PermLevel -eq 2) {
        Write-Host '  Step 3  Delete             [Read+Write] ⚠          — Remove stale non-Autopilot devices' -ForegroundColor Yellow
    }
    else {
        Write-Host '  Step 3  Delete             [Skipped — Read-Only session]' -ForegroundColor DarkGray
    }

    Write-Host ''
}

function Show-StepHeader {
    param(
        [int]$StepNumber,
        [string]$Title
    )
    Write-Host ''
    Write-Host ('─── Step {0}: {1} ' -f $StepNumber, $Title).PadRight(70, '─') -ForegroundColor Magenta
    Write-Host ''
}

function Read-MenuChoice {
    param(
        [string[]]$Options,
        [string]$Prompt = 'Select'
    )

    $i = 1
    foreach ($opt in $Options) {
        Write-Host ('  [{0}] {1}' -f $i, $opt)
        $i++
    }
    Write-Host ''

    $choice = $null
    do {
        $raw = Read-Host ('  ' + $Prompt)
        $choice = $raw -as [int]
    } while ($null -eq $choice -or $choice -lt 1 -or $choice -gt $Options.Count)

    return $choice
}

function Wait-Continue {
    param([string]$Message = 'Press ENTER to continue')
    Write-Host ''
    Read-Host ("  $Message") | Out-Null
}

# ─── Graph helpers ────────────────────────────────────────────────────────────

function Get-AllGraphPages {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [int]$MaxRetries = 3
    )

    $items = [System.Collections.Generic.List[object]]::new()
    $nextLink = $Uri

    while ($nextLink) {
        $response = $null
        $attempt = 0
        while ($attempt -lt $MaxRetries) {
            try {
                $response = Invoke-MgGraphRequest -Method GET -Uri $nextLink
                break
            }
            catch {
                $attempt++
                $msg = [string]$_.Exception.Message
                $retriable = $msg -match 'HTTP/\d+(\.\d+)?\s+(429|5\d\d)' -or
                $msg -match 'Too Many Requests|Internal Server Error|temporar'
                if (-not $retriable -or $attempt -ge $MaxRetries) { throw }
                $delay = [Math]::Min(15, [int][Math]::Pow(2, $attempt))
                Write-Host ("    Retrying in {0}s..." -f $delay) -ForegroundColor DarkYellow
                Start-Sleep -Seconds $delay
            }
        }
        $valueItems = Get-PropValue -Obj $response -Name 'value'
        if ($null -ne $valueItems) {
            foreach ($item in @($valueItems)) { $items.Add($item) }
        }
        $rawNextLink = [string](Get-PropValue -Obj $response -Name '@odata.nextLink')
        $nextLink = if ([string]::IsNullOrEmpty($rawNextLink)) { $null } else { $rawNextLink }
    }
    return , $items
}

function Get-PropValue {
    param(
        [object]$Obj,
        [string]$Name
    )

    if ($null -eq $Obj) { return $null }

    if ($Obj -is [System.Collections.IDictionary]) {
        if ($Obj.Contains($Name)) { return $Obj[$Name] }
        return $null
    }

    $prop = $Obj.PSObject.Properties.Match($Name) | Select-Object -First 1
    if ($prop) { return $prop.Value }
    return $null
}

function Test-HasZtdId {
    param([object[]]$PhysicalIds)

    if ($null -eq $PhysicalIds) { return $false }

    foreach ($entry in $PhysicalIds) {
        if ([string]$entry -match '^\[ZTDID\]:') { return $true }
    }
    return $false
}

# ─── Step 0: Authentication ───────────────────────────────────────────────────

function Invoke-Step0 {
    param([int]$PermLevel)

    Show-StepHeader -StepNumber 0 -Title 'Authentication'
    Write-Log -Step 0 -Message 'Authentication step started'

    $scopesRead = @('Device.Read.All', 'DeviceManagementServiceConfig.Read.All')
    $scopesWrite = @('Device.Read.All', 'Device.ReadWrite.All', 'DeviceManagementServiceConfig.Read.All')

    $scopes = if ($PermLevel -eq 1) { $scopesRead } else { $scopesWrite }

    # ── Auth method ───────────────────────────────────────────────────────────
    Write-Host '  Select sign-in method:' -ForegroundColor Cyan
    $authChoice = Read-MenuChoice -Options @(
        'Interactive browser / WAM  (current signed-in user, recommended)'
        'Interactive browser with UPN hint  (specify account upfront)'
        'App Registration  (Client ID + Tenant ID + Client Secret)'
    ) -Prompt 'Sign-in method'

    # Disconnect any stale session first
    try { Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null } catch {}

    switch ($authChoice) {
        1 {
            Write-Host ''
            Write-Host '  Opening browser / WAM prompt...' -ForegroundColor Gray
            Write-Log -Step 0 -Message 'Auth method: WAM / Interactive browser'
            Connect-MgGraph -Scopes $scopes -NoWelcome | Out-Null
        }

        2 {
            Write-Host ''
            $upn = (Read-Host '  UPN  (e.g. admin@contoso.com)').Trim()
            # Derive tenant domain from UPN for -TenantId hint (e.g. admin@contoso.com → contoso.com)
            $tenantHint = if ($upn -match '@(.+)$') { $Matches[1] } else { $null }
            Write-Host ('  Opening browser — sign in as {0}...' -f $upn) -ForegroundColor Gray
            Write-Log -Step 0 -Message ('Auth method: Interactive with UPN hint ({0}), TenantHint={1}' -f $upn, $tenantHint)
            if ($tenantHint) {
                Connect-MgGraph -Scopes $scopes -NoWelcome -TenantId $tenantHint | Out-Null
            }
            else {
                Connect-MgGraph -Scopes $scopes -NoWelcome | Out-Null
            }
        }

        3 {
            Write-Host ''
            $tenantId = (Read-Host '  Tenant ID').Trim()
            $clientId = (Read-Host '  Client ID').Trim()
            $secret = Read-Host '  Client Secret' -AsSecureString
            Write-Log -Step 0 -Message ('Auth method: App Registration. TenantId={0} ClientId={1}' -f $tenantId, $clientId)

            $cred = [System.Management.Automation.PSCredential]::new($clientId, $secret)
            Connect-MgGraph -TenantId $tenantId -ClientSecretCredential $cred -NoWelcome | Out-Null
        }
    }

    $ctx = Get-MgContext
    Write-Host ''
    Write-Host ('  Signed in as : {0}' -f $(if ($ctx.Account) { $ctx.Account } else { 'App: ' + $ctx.ClientId })) -ForegroundColor Green
    Write-Host ('  Tenant       : {0}' -f $ctx.TenantId) -ForegroundColor Green
    Write-Host ('  Scopes       : {0}' -f ($ctx.Scopes -join ', ')) -ForegroundColor Green

    Write-Log -Step 0 -Message ('Authenticated. Account={0} TenantId={1} Scopes={2}' -f $(if ($ctx.Account) { $ctx.Account } else { $ctx.ClientId }), $ctx.TenantId, ($ctx.Scopes -join ','))
    Write-Log -Step 0 -Message ('Permission level: {0}' -f $(if ($PermLevel -eq 1) { 'Read-only' } else { 'Read+Write' }))

    $logFile = Join-Path $script:LogDir ('{0}_Step0.log' -f $script:SessionTs)
    Write-Host ('  Log: {0}' -f $logFile) -ForegroundColor DarkGray

    return
}

# ─── Step 1: List all devices ─────────────────────────────────────────────────

function Invoke-Step1 {
    Show-StepHeader -StepNumber 1 -Title 'List All Entra Devices'
    Write-Log -Step 1 -Message 'Listing all Entra devices'

    # ── Entra devices ─────────────────────────────────────────────────────────
    Write-Host '  Querying Entra devices...' -ForegroundColor Gray

    $deviceUri = (
        'https://graph.microsoft.com/v1.0/devices' +
        '?$select=id,deviceId,displayName,operatingSystem,trustType,' +
        'approximateLastSignInDateTime,physicalIds,accountEnabled,isCompliant' +
        '&$expand=registeredOwners'
    )
    $rawDevices = Get-AllGraphPages -Uri $deviceUri
    Write-Host ('  Retrieved {0} device(s) from Entra.' -f $rawDevices.Count) -ForegroundColor Gray

    # ── Autopilot lookup (ZTDID primary; registration cross-check fallback) ───
    Write-Host '  Querying Autopilot registrations...' -ForegroundColor Gray

    $autopilotLookup = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $autopilotAvailable = $true
    try {
        $apDevices = Get-AllGraphPages -Uri 'https://graph.microsoft.com/v1.0/deviceManagement/windowsAutopilotDeviceIdentities'
        foreach ($ap in $apDevices) {
            $aadId = [string](Get-PropValue -Obj $ap -Name 'azureActiveDirectoryDeviceId')
            if (-not [string]::IsNullOrWhiteSpace($aadId)) {
                [void]$autopilotLookup.Add($aadId.Trim())
            }
        }
        Write-Host ('  Retrieved {0} Autopilot registration(s).' -f $autopilotLookup.Count) -ForegroundColor Gray
        Write-Log -Step 1 -Message ('Autopilot cross-check: {0} registrations loaded.' -f $autopilotLookup.Count)
    }
    catch {
        $autopilotAvailable = $false
        Write-Log -Step 1 -Message 'Autopilot registration query failed. Falling back to ZTDID-only check.' -Level WARN
    }

    # ── Enrich ────────────────────────────────────────────────────────────────
    # Nested progress for enrichment loop
    $rawTotal = if ($null -eq $rawDevices) { 0 } else { $rawDevices.Count }
    $rawIndex = 0
    Write-Verbose ('Enriching {0} device(s)...' -f $rawTotal)

    $enriched = foreach ($d in $rawDevices) {
        # Update nested progress
        $rawIndex++
        $displayName = [string](Get-PropValue -Obj $d -Name 'displayName')
        $devId = [string](Get-PropValue -Obj $d -Name 'deviceId')
        $objId = [string](Get-PropValue -Obj $d -Name 'id')
        $deviceDisplay = if (-not [string]::IsNullOrWhiteSpace($displayName)) { $displayName } elseif (-not [string]::IsNullOrWhiteSpace($devId)) { $devId } else { $objId }
        $progressPct = [int](($rawIndex / [Math]::Max(1, $rawTotal)) * 100)
        Write-Progress -Activity 'Listing devices' -Status ('{0}/{1}: {2}' -f $rawIndex, $rawTotal, $deviceDisplay) -PercentComplete $progressPct
        $owners = Get-PropValue -Obj $d -Name 'registeredOwners'
        $ownerUpn = ''
        if ($owners -and ($owners | Measure-Object).Count -gt 0) {
            $ownerUpn = [string](Get-PropValue -Obj $owners[0] -Name 'userPrincipalName')
        }

        $lastSignInRaw = [string](Get-PropValue -Obj $d -Name 'approximateLastSignInDateTime')
        $lastSignIn = $null
        $daysSince = [int]9999   # sentinel for "never signed in / unknown"

        if (-not [string]::IsNullOrWhiteSpace($lastSignInRaw)) {
            try {
                $ts = [DateTimeOffset]::Parse($lastSignInRaw)
                $lastSignIn = $ts.UtcDateTime
                $daysSince = [int][Math]::Floor(([DateTime]::UtcNow - $ts.UtcDateTime).TotalDays)
            }
            catch {
                Write-Log -Step 1 -Message ('Could not parse date for device {0}' -f (Get-PropValue -Obj $d -Name 'id')) -Level WARN
            }
        }

        $physIds = Get-PropValue -Obj $d -Name 'physicalIds'
        $isAutopilotZtdId = Test-HasZtdId -PhysicalIds $physIds
        $isAutopilotReg = $false
        if ($autopilotAvailable) {
            $devId = [string](Get-PropValue -Obj $d -Name 'deviceId')
            $objId = [string](Get-PropValue -Obj $d -Name 'id')
            if (-not [string]::IsNullOrWhiteSpace($devId)) { $isAutopilotReg = $autopilotLookup.Contains($devId.Trim()) }
            if (-not $isAutopilotReg -and -not [string]::IsNullOrWhiteSpace($objId)) { $isAutopilotReg = $autopilotLookup.Contains($objId.Trim()) }
        }

        [PSCustomObject]@{
            DisplayName   = [string](Get-PropValue -Obj $d -Name 'displayName')
            OS            = [string](Get-PropValue -Obj $d -Name 'operatingSystem')
            TrustType     = [string](Get-PropValue -Obj $d -Name 'trustType')
            Owner         = $ownerUpn
            LastSignIn    = if ($lastSignIn) { $lastSignIn.ToString('yyyy-MM-dd') } else { 'Unknown' }
            DaysSince     = $daysSince
            Enabled       = [bool](Get-PropValue -Obj $d -Name 'accountEnabled')
            Compliant     = [bool](Get-PropValue -Obj $d -Name 'isCompliant')
            IsAutopilot   = $isAutopilotZtdId -or $isAutopilotReg
            EntraObjectId = [string](Get-PropValue -Obj $d -Name 'id')
            EntraDeviceId = [string](Get-PropValue -Obj $d -Name 'deviceId')
        }
    }

    # Ensure nested progress is completed
    Write-Progress -Activity 'Listing devices' -Completed

    # ── Display ───────────────────────────────────────────────────────────────
    $total = ($enriched | Measure-Object).Count
    Write-Host ''
    Write-Host ('  {0} device(s) found. Sorted by last activity (oldest first):' -f $total) -ForegroundColor Cyan
    Write-Host ''

    $enriched |
    Sort-Object DaysSince -Descending |
    Format-Table DisplayName, OS, TrustType, Owner, LastSignIn, DaysSince, Enabled, Compliant, IsAutopilot -AutoSize |
    Out-Host

    # ── Log ───────────────────────────────────────────────────────────────────
    Write-LogCsv -Rows @($enriched | Sort-Object DaysSince -Descending) -Step '1'
    Write-Log -Step 1 -Message ('Devices listed: {0}. Autopilot cross-check available: {1}.' -f $total, $autopilotAvailable)

    $logFile = Join-Path $script:LogDir ('{0}_Step1.log' -f $script:SessionTs)
    Write-Host ('  Log: {0}' -f $logFile) -ForegroundColor DarkGray

    # Filter out any $null entries that result from an empty foreach
    return @($enriched | Where-Object { $null -ne $_ })
}

# ─── Step 2: Filter by staleness threshold ────────────────────────────────────

function Invoke-Step2 {
    param([object[]]$Devices)

    Show-StepHeader -StepNumber 2 -Title 'Filter by Staleness Threshold'

    Write-Host '  Select the staleness threshold:' -ForegroundColor Cyan
    $threshChoice = Read-MenuChoice -Options @(
        ' 30 days  — aggressive   (recently inactive only)'
        ' 90 days  — recommended'
        '365 days  — conservative (one year or more inactive)'
        'Custom    — enter any number of days'
    ) -Prompt 'Threshold'

    if ($threshChoice -eq 4) {
        $customDays = $null
        do {
            $raw = Read-Host '  Enter custom threshold (days)'
            $customDays = $raw -as [int]
            if ($null -eq $customDays -or $customDays -lt 1) {
                Write-Host '  Please enter a positive integer.' -ForegroundColor Yellow
                $customDays = $null
            }
        } while ($null -eq $customDays)
        $threshold = $customDays
    }
    else {
        $threshold = @(30, 90, 365)[$threshChoice - 1]
    }
    Write-Log -Step 2 -Message ('Threshold selected: {0} days' -f $threshold)

    # Devices with DaysSince = 9999 (no sign-in recorded) are listed separately
    $stale = @($Devices | Where-Object { $null -ne $_ -and $_.DaysSince -ne 9999 -and $_.DaysSince -ge $threshold })
    $nonAp = @($stale   | Where-Object { $null -ne $_ -and -not $_.IsAutopilot })
    $apDev = @($stale   | Where-Object { $null -ne $_ -and $_.IsAutopilot })
    $noLogin = @($Devices  | Where-Object { $null -ne $_ -and $_.DaysSince -eq 9999 })

    Write-Host ''
    Write-Host ('  Results for threshold >= {0} days' -f $threshold) -ForegroundColor Cyan
    Write-Host ('  ─────────────────────────────────────────────') -ForegroundColor DarkGray
    Write-Host ('  Total stale             : {0}' -f $stale.Count)
    Write-Host ('  Non-Autopilot (eligible): {0}' -f $nonAp.Count)   -ForegroundColor Yellow
    Write-Host ('  Autopilot (protected)   : {0}' -f $apDev.Count)    -ForegroundColor Green
    Write-Host ('  No sign-in recorded     : {0}' -f $noLogin.Count)  -ForegroundColor DarkGray
    Write-Host ''

    if ($nonAp.Count -gt 0) {
        Write-Host '  Non-Autopilot stale devices eligible for deletion:' -ForegroundColor Yellow
        Write-Host ''
        $nonAp |
        Sort-Object DaysSince -Descending |
        Format-Table DisplayName, OS, TrustType, Owner, LastSignIn, DaysSince, Enabled -AutoSize |
        Out-Host
    }
    else {
        Write-Host '  No non-Autopilot stale devices found for this threshold.' -ForegroundColor Green
    }

    Write-LogCsv -Rows @($nonAp | Sort-Object DaysSince -Descending) -Step '2'
    Write-Log -Step 2 -Message ('Filter complete. Threshold={0}d Stale={1} NonAutopilot={2} Autopilot={3} NoSignIn={4}' -f $threshold, $stale.Count, $nonAp.Count, $apDev.Count, $noLogin.Count)

    $logFile = Join-Path $script:LogDir ('{0}_Step2.log' -f $script:SessionTs)
    Write-Host ('  Log: {0}' -f $logFile) -ForegroundColor DarkGray

    return [PSCustomObject]@{
        Threshold    = $threshold
        NonAutopilot = $nonAp
        Autopilot    = $apDev
    }
}

# ─── Step 3: Delete non-Autopilot stale devices ───────────────────────────────

function Invoke-Step3 {
    param(
        [object[]]$DevicesToDelete,
        [int]$Threshold
    )

    Show-StepHeader -StepNumber 3 -Title ('Delete Non-Autopilot Devices Older Than {0} Days' -f $Threshold)
    Write-Log -Step 3 -Message ('Delete step started. Candidates: {0}' -f $DevicesToDelete.Count)

    if ($DevicesToDelete.Count -eq 0) {
        Write-Host '  No eligible devices to delete.' -ForegroundColor Green
        Write-Log -Step 3 -Message 'No eligible devices to delete. Step skipped.'
        return
    }

    # ── Final confirmation ────────────────────────────────────────────────────
    Write-Host ('  {0} device(s) will be permanently deleted from Entra ID.' -f $DevicesToDelete.Count) -ForegroundColor Yellow
    Write-Host '  Autopilot devices have already been excluded.' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  ┌──────────────────────────────────────────────────────────┐' -ForegroundColor Red
    Write-Host '  │  This action is IRREVERSIBLE. Devices will be removed    │' -ForegroundColor Red
    Write-Host '  │  from Entra ID. Type  yes  to confirm.                   │' -ForegroundColor Red
    Write-Host '  └──────────────────────────────────────────────────────────┘' -ForegroundColor Red
    Write-Host ''

    $confirm = (Read-Host '  Confirm deletion [yes/NO]').Trim()
    if ($confirm -ne 'yes') {
        Write-Host '  Deletion cancelled.' -ForegroundColor Green
        Write-Log -Step 3 -Message 'Deletion cancelled by user at confirmation prompt.'
        return
    }

    Write-Log -Step 3 -Message ('User confirmed deletion of {0} devices.' -f $DevicesToDelete.Count)
    Write-Host ''

    # ── Delete loop ───────────────────────────────────────────────────────────
    $deleted = 0
    $failed = 0

    foreach ($dev in ($DevicesToDelete | Sort-Object DaysSince -Descending)) {
        try {
            Invoke-MgGraphRequest -Method DELETE -Uri ('https://graph.microsoft.com/v1.0/devices/{0}' -f $dev.EntraObjectId)
            $deleted++
            Write-Host ('  [OK]  {0}  ({1}d)' -f $dev.DisplayName.PadRight(45), $dev.DaysSince) -ForegroundColor Green
            Write-Log -Step 3 -Message ('DELETED | {0} | ObjectId={1} | DeviceId={2} | DaysSince={3}' -f $dev.DisplayName, $dev.EntraObjectId, $dev.EntraDeviceId, $dev.DaysSince)
        }
        catch {
            $failed++
            $errMsg = [string]$_.Exception.Message
            Write-Host ('  [ERR] {0}  {1}' -f $dev.DisplayName.PadRight(45), $errMsg) -ForegroundColor Red
            Write-Log -Step 3 -Message ('FAILED  | {0} | ObjectId={1} | Error={2}' -f $dev.DisplayName, $dev.EntraObjectId, $errMsg) -Level ERROR
        }
    }

    Write-Host ''
    Write-Host ('  ─── Summary ────────────────────────────────────────────────') -ForegroundColor DarkGray
    Write-Host ('  Deleted : {0}' -f $deleted) -ForegroundColor Green
    Write-Host ('  Failed  : {0}' -f $failed)  -ForegroundColor $(if ($failed -gt 0) { 'Red' } else { 'Green' })

    Write-Log -Step 3 -Message ('Deletion complete. Deleted={0} Failed={1}' -f $deleted, $failed)

    $logFile = Join-Path $script:LogDir ('{0}_Step3.log' -f $script:SessionTs)
    Write-Host ('  Log: {0}' -f $logFile) -ForegroundColor DarkGray
}

# ─── Entry point ──────────────────────────────────────────────────────────────

Show-Banner

if (-not (Get-Command -Name Invoke-MgGraphRequest -ErrorAction SilentlyContinue)) {
    Write-Host '  ERROR: Microsoft Graph PowerShell SDK is not installed.' -ForegroundColor Red
    Write-Host '  Run:   Install-Module Microsoft.Graph -Scope CurrentUser' -ForegroundColor Yellow
    exit 1
}

$null = [System.IO.Directory]::CreateDirectory($script:LogDir)
Write-Log -Step 0 -Message ('Session started. LogDir={0}' -f $script:LogDir)

# ── Choose execution mode upfront ─────────────────────────────────────────────
Write-Host '  What do you want to do in this session?' -ForegroundColor Cyan
$permLevel = Read-MenuChoice -Options @(
    'Read-only   — list and filter devices (no deletion)'
    'Read+Write  — list, filter and delete stale devices'
) -Prompt 'Execution mode'

Write-Log -Step 0 -Message ('Execution mode selected: {0}' -f $(if ($permLevel -eq 1) { 'Read-only' } else { 'Read+Write' }))

# ── Show step overview based on chosen mode ───────────────────────────────────
Show-StepOverview -PermLevel $permLevel

# Step 0 — Auth
Invoke-Step0 -PermLevel $permLevel

# Step 1 — List
Wait-Continue -Message 'Press ENTER to continue to Step 1: List Devices'
$allDevices = @(@(Invoke-Step1) | Where-Object { $null -ne $_ })

if ($allDevices.Count -eq 0) {
    Write-Host ''
    Write-Host '  No devices found. Nothing to process.' -ForegroundColor Yellow
    Write-Log -Step 1 -Message 'No devices returned. Exiting.'
    exit 0
}

# Step 2 — Filter (threshold choice is the first interaction; no extra ENTER needed)
$filterResult = Invoke-Step2 -Devices $allDevices

# Step 3 — Delete (write mode only)
if ($permLevel -eq 2) {
    if ($filterResult.NonAutopilot.Count -gt 0) {
        Wait-Continue -Message 'Press ENTER to continue to Step 3: Delete'
        Invoke-Step3 -DevicesToDelete $filterResult.NonAutopilot -Threshold $filterResult.Threshold
    }
    else {
        Write-Host ''
        Write-Host '  Step 3 skipped — no eligible devices to delete.' -ForegroundColor Green
        Write-Log -Step 3 -Message 'Step 3 skipped — no eligible non-Autopilot devices after filter.'
    }
}
else {
    Write-Host ''
    Write-Host '  Step 3 skipped — session is read-only.' -ForegroundColor DarkGray
    Write-Log -Step 3 -Message 'Step 3 skipped — read-only session.'
}

# ─── Done ─────────────────────────────────────────────────────────────────────
Write-Host ''
Write-Host ('=' * 70) -ForegroundColor Magenta
Write-Host ('  Done. Session logs: {0}' -f $script:LogDir) -ForegroundColor Cyan
Write-Host ('=' * 70) -ForegroundColor Magenta
Write-Host ''

Write-Log -Step 0 -Message 'Session complete.'
