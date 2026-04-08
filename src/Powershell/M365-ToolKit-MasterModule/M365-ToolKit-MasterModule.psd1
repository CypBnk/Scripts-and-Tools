@{
    RootModule        = 'M365-ToolKit-MasterModule.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '6f01f85f-e6bb-4b89-95b5-c5b774554696'
    Author            = 'Scripts-and-Tools'
    CompanyName       = 'Internal'
    Copyright         = '(c) Scripts-and-Tools. All rights reserved.'
    Description       = 'Master module orchestrator for M365 workload tools with GUI launcher.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Invoke-M365Toolkit',
        'Get-M365ToolkitCatalog'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags = @('M365', 'Toolkit', 'GUI', 'Exchange', 'Entra', 'Intune')
        }
    }
}