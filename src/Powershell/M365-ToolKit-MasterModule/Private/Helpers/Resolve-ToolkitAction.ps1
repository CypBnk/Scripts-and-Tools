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
    $actionArgs = @()
    if ($PSBoundParameters.ContainsKey('ArgsOverride')) {
        $actionArgs = @($ArgsOverride | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    }
    elseif ($null -ne $Action.Args) {
        $actionArgs = @($Action.Args)
    }

    $splatParams = ConvertTo-SplatHashtable -ArgumentList $actionArgs

    try {
        if ($Action.RunType -eq 'ModuleCommand') {
            $modulePath = Join-Path $root $Action.TargetPath
            Write-ToolkitLog -Level INFO -Source 'Resolve-ToolkitAction' -Message "Importing module '$modulePath' and running '$($Action.Command)'"
            Import-Module -Name $modulePath -Force -ErrorAction Stop
            & $Action.Command @splatParams
        }
        elseif ($Action.RunType -eq 'Script') {
            $scriptPath = Join-Path $root $Action.TargetPath
            Write-ToolkitLog -Level INFO -Source 'Resolve-ToolkitAction' -Message "Running script '$scriptPath'"
            & $scriptPath @splatParams
        }
        else {
            Write-ToolkitLog -Level ERROR -Source 'Resolve-ToolkitAction' -Message "Unsupported RunType: $($Action.RunType)"
            throw "Unsupported RunType: $($Action.RunType)"
        }

        Write-ToolkitLog -Level INFO -Source 'Resolve-ToolkitAction' -Message "Action completed: $($Action.DisplayName)"
        return [pscustomobject]@{
            Success = $true
            Message = "Action completed successfully: $($Action.DisplayName)"
        }
    }
    catch {
        Write-ToolkitLog -Level ERROR -Source 'Resolve-ToolkitAction' -Message "Action failed: $($Action.DisplayName)" -ErrorRecord $_
        return [pscustomobject]@{
            Success = $false
            Message = $_.Exception.Message
        }
    }
}