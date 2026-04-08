function Resolve-ToolkitAction {
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

    $root = Get-ToolkitRoot
    $args = @()
    if ($PSBoundParameters.ContainsKey('ArgsOverride')) {
        $args = @($ArgsOverride | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    }
    elseif ($null -ne $Action.Args) {
        $args = @($Action.Args)
    }

    try {
        if ($Action.RunType -eq 'ModuleCommand') {
            $modulePath = Join-Path $root $Action.TargetPath
            Import-Module -Name $modulePath -Force -ErrorAction Stop
            & $Action.Command @args
        }
        elseif ($Action.RunType -eq 'Script') {
            $scriptPath = Join-Path $root $Action.TargetPath
            & $scriptPath @args
        }
        else {
            throw "Unsupported RunType: $($Action.RunType)"
        }

        return [pscustomobject]@{
            Success = $true
            Message = "Action completed successfully: $($Action.DisplayName)"
        }
    }
    catch {
        return [pscustomobject]@{
            Success = $false
            Message = $_.Exception.Message
        }
    }
}