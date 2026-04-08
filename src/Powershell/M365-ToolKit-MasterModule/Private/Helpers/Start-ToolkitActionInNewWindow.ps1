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
            Action       = [ordered]@{
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

        $logFile = Join-Path $toolkitRoot 'Output\M365Toolkit.log'
        $logFileB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($logFile))

        $childScript = @"
`$ErrorActionPreference = 'Stop'
`$payloadB64 = '$payloadB64'
`$toolkitRootB64 = '$toolkitRootB64'
`$logFileB64 = '$logFileB64'

`$payloadJson = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(`$payloadB64))
`$toolkitRoot = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(`$toolkitRootB64))
`$logFile = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(`$logFileB64))
`$payload = `$payloadJson | ConvertFrom-Json
`$action = `$payload.Action
`$flatArgs = @(`$payload.ArgsOverride)

# Convert flat args array to hashtable for splatting (avoids positional binding issues from JSON)
`$splatParams = [ordered]@{}
`$i = 0
while (`$i -lt `$flatArgs.Count) {
    `$token = [string]`$flatArgs[`$i]
    if (`$token.StartsWith('-')) {
        `$stripped = `$token.Substring(1)
        `$spaceIdx = `$stripped.IndexOf(' ')
        if (`$spaceIdx -gt 0) {
            `$paramName = `$stripped.Substring(0, `$spaceIdx)
            `$paramValue = `$stripped.Substring(`$spaceIdx + 1).Trim().Trim('"', "'")
            `$splatParams[`$paramName] = `$paramValue
            `$i += 1
        } else {
            `$paramName = `$stripped
            `$nextIndex = `$i + 1
            if (`$nextIndex -lt `$flatArgs.Count -and -not ([string]`$flatArgs[`$nextIndex]).StartsWith('-')) {
                `$splatParams[`$paramName] = `$flatArgs[`$nextIndex]
                `$i += 2
            } else {
                `$splatParams[`$paramName] = `$true
                `$i += 1
            }
        }
    } else {
        `$i += 1
    }
}

function Write-ChildLog {
    param([string]`$Level, [string]`$Message, [string]`$Detail)
    `$logDir = [System.IO.Path]::GetDirectoryName(`$logFile)
    if (-not (Test-Path -Path `$logDir)) { New-Item -Path `$logDir -ItemType Directory -Force | Out-Null }
    `$ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'
    `$entry = "[`$ts] [`$Level] [ChildWindow] `$Message"
    if (`$Detail) { `$entry += "`n  Detail    : `$Detail" }
    Add-Content -Path `$logFile -Value `$entry -Encoding UTF8
}

if (`$action.IsPlaceholder) {
    throw 'Selected action is a placeholder and cannot be executed.'
}

Write-Host "Running: `$(`$action.DisplayName)" -ForegroundColor Cyan
Write-Host "Workload: `$(`$action.Workload)" -ForegroundColor DarkGray
Write-Host "Args: `$(`$flatArgs -join ' ')" -ForegroundColor DarkGray

try {
    if (`$action.RunType -eq 'ModuleCommand') {
        `$modulePath = Join-Path `$toolkitRoot `$action.TargetPath
        Write-Host "Importing: `$modulePath" -ForegroundColor DarkGray
        Import-Module -Name `$modulePath -Force -ErrorAction Stop
        & `$action.Command @splatParams
    }
    elseif (`$action.RunType -eq 'Script') {
        `$scriptPath = Join-Path `$toolkitRoot `$action.TargetPath
        & `$scriptPath @splatParams
    }
    else {
        throw "Unsupported RunType: `$(`$action.RunType)"
    }

    Write-Host "Completed: `$(`$action.DisplayName)" -ForegroundColor Green
    Write-ChildLog -Level INFO -Message "Action completed in child window: `$(`$action.DisplayName)"
}
catch {
    Write-Host ("Action failed: " + `$_.Exception.Message) -ForegroundColor Red
    Write-Host `$_.ScriptStackTrace -ForegroundColor DarkRed
    `$detail = `$_.Exception.Message
    if (`$_.ScriptStackTrace) { `$detail += "`n  StackTrace: `$(`$_.ScriptStackTrace)" }
    if (`$_.InvocationInfo -and `$_.InvocationInfo.PositionMessage) { `$detail += "`n  Position  : `$(`$_.InvocationInfo.PositionMessage)" }
    Write-ChildLog -Level ERROR -Message "Action failed in child window: `$(`$action.DisplayName)" -Detail `$detail
}
"@

        $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($childScript))

        $shellExe = if (Get-Command -Name 'pwsh.exe' -ErrorAction SilentlyContinue) {
            'pwsh.exe'
        }
        else {
            'powershell.exe'
        }

        Start-Process -FilePath $shellExe -ArgumentList @('-NoExit', '-NoProfile', '-EncodedCommand', $encodedCommand) | Out-Null

        Write-ToolkitLog -Level INFO -Source 'Start-ToolkitActionInNewWindow' -Message "Spawned new window for action: $($Action.DisplayName) with args: $($effectiveArgs -join ' ')"
        [pscustomobject]@{
            Success = $true
            Message = "Spawned new PowerShell window for action: $($Action.DisplayName)"
        }
    }
    catch {
        Write-ToolkitLog -Level ERROR -Source 'Start-ToolkitActionInNewWindow' -Message "Failed to launch new window for: $($Action.DisplayName)" -ErrorRecord $_
        [pscustomobject]@{
            Success = $false
            Message = $_.Exception.Message
        }
    }
}