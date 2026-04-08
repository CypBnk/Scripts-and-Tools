function Start-ToolkitActionInNewWindow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [pscustomobject]$Action,

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$ArgsOverride
    )

    if ($Action.IsPlaceholder) {
        return [pscustomobject]@{
            Success = $false
            Message = 'This workload is a placeholder in v1 and has no runnable action yet.'
        }
    }

    try {
        $effectiveArgs = @()
        if ($PSBoundParameters.ContainsKey('ArgsOverride') -and $null -ne $ArgsOverride -and @($ArgsOverride).Count -gt 0) {
            $effectiveArgs = @($ArgsOverride | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
        }
        elseif ($null -ne $Action.Args) {
            $effectiveArgs = @($Action.Args)
        }

        $payload = [ordered]@{
            Action = [ordered]@{
                Workload      = [string]$Action.Workload
                ModuleName    = [string]$Action.ModuleName
                DisplayName   = [string]$Action.DisplayName
                RunType       = [string]$Action.RunType
                Command       = [string]$Action.Command
                TargetPath    = [string]$Action.TargetPath
                IsPlaceholder = [bool]$Action.IsPlaceholder
            }
            ArgsOverride = @($effectiveArgs)
        }

        $payloadJson = $payload | ConvertTo-Json -Depth 8 -Compress
        $payloadB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($payloadJson))

        $toolkitRoot = Get-ToolkitRoot
        $toolkitRootB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($toolkitRoot))

        $childScript = @"
`$payloadB64 = '$payloadB64'
`$toolkitRootB64 = '$toolkitRootB64'

`$payloadJson = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(`$payloadB64))
`$toolkitRoot = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(`$toolkitRootB64))
`$payload = `$payloadJson | ConvertFrom-Json
`$action = `$payload.Action
`$args = @(`$payload.ArgsOverride)

if (`$action.IsPlaceholder) {
    throw 'Selected action is a placeholder and cannot be executed.'
}

Write-Host "Running: `$(`$action.DisplayName)" -ForegroundColor Cyan
Write-Host "Workload: `$(`$action.Workload)" -ForegroundColor DarkGray

if (`$action.RunType -eq 'ModuleCommand') {
    `$modulePath = Join-Path `$toolkitRoot `$action.TargetPath
    Import-Module -Name `$modulePath -Force -ErrorAction Stop
    & `$action.Command @args
}
elseif (`$action.RunType -eq 'Script') {
    `$scriptPath = Join-Path `$toolkitRoot `$action.TargetPath
    & `$scriptPath @args
}
else {
    throw "Unsupported RunType: `$(`$action.RunType)"
}

Write-Host "Completed: `$(`$action.DisplayName)" -ForegroundColor Green
"@

        $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($childScript))

        $shellExe = if (Get-Command -Name 'pwsh.exe' -ErrorAction SilentlyContinue) {
            'pwsh.exe'
        }
        else {
            'powershell.exe'
        }

        Start-Process -FilePath $shellExe -ArgumentList @('-NoExit', '-NoProfile', '-EncodedCommand', $encodedCommand) | Out-Null

        [pscustomobject]@{
            Success = $true
            Message = "Spawned new PowerShell window for action: $($Action.DisplayName)"
        }
    }
    catch {
        [pscustomobject]@{
            Success = $false
            Message = $_.Exception.Message
        }
    }
}function Start-ToolkitActionInNewWindow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [pscustomobject]$Action,

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$ArgsOverride
    )

    if ($Action.IsPlaceholder) {
        return [pscustomobject]@{
            Success = $false
            Message = 'This workload is a placeholder in v1 and has no runnable action yet.'
        }
    }

    $shellCmd = if (Get-Command -Name 'pwsh.exe' -ErrorAction SilentlyContinue) { 'pwsh.exe' } else { 'powershell.exe' }
    $moduleRoot = Get-ToolkitRoot

    $runType = [string]$Action.RunType
    $commandName = [string]$Action.Command
    $targetPath = [string]$Action.TargetPath
    $targetFullPath = if ([string]::IsNullOrWhiteSpace($targetPath)) { '' } else { Join-Path $moduleRoot $targetPath }

    $argsToUse = @()
    if ($PSBoundParameters.ContainsKey('ArgsOverride')) {
        $argsToUse = @($ArgsOverride | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    }
    elseif ($null -ne $Action.Args) {
        $argsToUse = @($Action.Args)
    }

    $argsPayload = ($argsToUse | ConvertTo-Json -Compress)

    $scriptContent = @"
`$ErrorActionPreference = 'Stop'
`$runType = '$runType'
`$commandName = '$commandName'
`$targetPath = '$targetFullPath'
`$argsToUse = @($argsPayload | ConvertFrom-Json)

Write-Host "Running action: $($Action.DisplayName)" -ForegroundColor Cyan
Write-Host "Target: `$targetPath" -ForegroundColor DarkGray

try {
    if (`$runType -eq 'ModuleCommand') {
        Import-Module -Name `$targetPath -Force -ErrorAction Stop
        & `$commandName @argsToUse
    }
    elseif (`$runType -eq 'Script') {
        & `$targetPath @argsToUse
    }
    else {
        throw "Unsupported RunType: `$runType"
    }

    Write-Host 'Action completed successfully.' -ForegroundColor Green
}
catch {
    Write-Host ("Action failed: " + `$_.Exception.Message) -ForegroundColor Red
}
"@

    $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($scriptContent))
    $startArgs = @('-NoExit', '-EncodedCommand', $encoded)

    Start-Process -FilePath $shellCmd -ArgumentList $startArgs | Out-Null

    [pscustomobject]@{
        Success = $true
        Message = 'Launched action in new PowerShell window.'
    }
}