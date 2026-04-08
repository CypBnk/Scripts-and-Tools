$moduleManifest = Join-Path $PSScriptRoot '..\..\M365-ToolKit-MasterModule.psd1'
Import-Module $moduleManifest -Force

Describe 'Test-ToolkitActionPrerequisites' {
    It 'flags placeholder workloads as not runnable' {
        InModuleScope M365-ToolKit-MasterModule {
            $action = [pscustomobject]@{
                DisplayName   = 'Planned action'
                IsPlaceholder = $true
                TargetPath    = ''
            }

            $result = Test-ToolkitActionPrerequisites -Action $action
            $result.Success | Should Be $false
            $result.Summary | Should Match 'Placeholder'
        }
    }

    It 'passes target-path check for catalog action file' {
        InModuleScope M365-ToolKit-MasterModule {
            $catalog = Get-ToolkitCatalog
            $action = @($catalog | Where-Object { -not $_.IsPlaceholder } | Select-Object -First 1)[0]

            $result = Test-ToolkitActionPrerequisites -Action $action
            @($result.Checks | Where-Object { $_.Name -eq 'Target path exists' -and $_.Passed }).Count | Should Be 1
        }
    }

    It 'handles actions that do not expose a Prerequisites property' {
        InModuleScope M365-ToolKit-MasterModule {
            $action = [pscustomobject]@{
                DisplayName   = 'Projected action'
                IsPlaceholder = $false
                TargetPath    = 'M365-ToolKit-MasterModule.psd1'
            }

            { Test-ToolkitActionPrerequisites -Action $action } | Should Not Throw
            $result = Test-ToolkitActionPrerequisites -Action $action
            @($result.Checks | Where-Object { $_.Name -eq 'Target path exists' -and $_.Passed }).Count | Should Be 1
        }
    }
}
