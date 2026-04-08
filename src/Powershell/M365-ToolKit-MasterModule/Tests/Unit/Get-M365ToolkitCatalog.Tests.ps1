$moduleManifest = Join-Path $PSScriptRoot '..\..\M365-ToolKit-MasterModule.psd1'
Import-Module $moduleManifest -Force

Describe 'Get-M365ToolkitCatalog' {
    It 'returns non-placeholder actions by default' {
        $items = Get-M365ToolkitCatalog
        @($items).Count | Should BeGreaterThan 0
        (@($items | Where-Object { $_.IsPlaceholder }).Count) | Should Be 0
    }

    It 'returns placeholder workloads when requested' {
        $items = Get-M365ToolkitCatalog -IncludePlaceholders
        (@($items | Where-Object { $_.Workload -eq 'SharePoint' -and $_.IsPlaceholder }).Count) | Should Be 1
        (@($items | Where-Object { $_.Workload -eq 'Teams' -and $_.IsPlaceholder }).Count) | Should Be 1
    }

    It 'filters by workload' {
        $items = Get-M365ToolkitCatalog -Workload Entra -IncludePlaceholders
        (@($items).Count) | Should BeGreaterThan 0
        (@($items | Where-Object { $_.Workload -ne 'Entra' }).Count) | Should Be 0
    }
}