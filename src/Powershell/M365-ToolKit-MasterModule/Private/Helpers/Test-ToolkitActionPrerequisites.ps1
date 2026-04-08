function Test-ToolkitActionPrerequisites {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [pscustomobject]$Action
    )

    $checks = @()

    if ($Action.IsPlaceholder) {
        return [pscustomobject]@{
            Success = $false
            Summary = 'Placeholder workload. No runnable action in v1.'
            Checks  = @(
                [pscustomobject]@{
                    Name   = 'Placeholder workload'
                    Passed = $false
                    Detail = 'This action is intentionally not runnable yet.'
                }
            )
        }
    }

    $root = Get-ToolkitRoot
    $targetPath = if ([string]::IsNullOrWhiteSpace([string]$Action.TargetPath)) { $null } else { Join-Path $root $Action.TargetPath }
    $targetExists = $false
    if ($targetPath) {
        $targetExists = Test-Path -Path $targetPath -PathType Leaf
    }

    $checks += [pscustomobject]@{
        Name   = 'Target path exists'
        Passed = $targetExists
        Detail = if ($targetExists) { $targetPath } else { "Missing target file: $targetPath" }
    }

    $requiredModules = @()
    $requiredCommands = @()
    if ($null -ne $Action.Prerequisites) {
        if ($null -ne $Action.Prerequisites.Modules) {
            $requiredModules = @($Action.Prerequisites.Modules)
        }
        if ($null -ne $Action.Prerequisites.Commands) {
            $requiredCommands = @($Action.Prerequisites.Commands)
        }
    }

    foreach ($moduleName in $requiredModules) {
        $isPresent = $null -ne (Get-Module -Name $moduleName -ListAvailable -ErrorAction SilentlyContinue | Select-Object -First 1)
        $checks += [pscustomobject]@{
            Name   = "Module: $moduleName"
            Passed = $isPresent
            Detail = if ($isPresent) { 'Available' } else { 'Not installed or not discoverable in current environment' }
        }
    }

    foreach ($commandName in $requiredCommands) {
        $cmd = Get-Command -Name $commandName -ErrorAction SilentlyContinue
        $isPresent = $null -ne $cmd
        $checks += [pscustomobject]@{
            Name   = "Command: $commandName"
            Passed = $isPresent
            Detail = if ($isPresent) { 'Available' } else { 'Not available in current session' }
        }
    }

    $failedCount = @($checks | Where-Object { -not $_.Passed }).Count
    [pscustomobject]@{
        Success = ($failedCount -eq 0)
        Summary = if ($failedCount -eq 0) { 'Preflight passed.' } else { "Preflight found $failedCount issue(s)." }
        Checks  = @($checks)
    }
}