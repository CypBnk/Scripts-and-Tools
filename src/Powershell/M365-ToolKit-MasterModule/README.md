# M365 ToolKit Master Module

This folder contains the first implementation of a copy-based orchestrator for M365 workload tooling.

## Scope

- Existing source modules remain in place and unchanged.
- Operational copies are placed under `Modules/` in this folder.
- GUI v1 is XAML/WPF-first, with an HTML scaffold available.

## Workloads in v1

- Entra
- Intune
- Exchange
- OnPrem-X-Cloud
- SharePoint (placeholder)
- Teams (placeholder)

## Quickstart

```powershell
Import-Module .\src\Powershell\M365-ToolKit-MasterModule\M365-ToolKit-MasterModule.psd1 -Force
Get-M365ToolkitCatalog -IncludePlaceholders
Invoke-M365Toolkit -Interface Xaml
```

## Structure

- `Public/`: exported entry cmdlets
- `Private/`: internal helpers and GUI core
- `Modules/`: copied source workload assets and action catalog
- `GUI/XAML/`: primary desktop UI
- `GUI/HTML/`: future web-style UI scaffold

## Notes

- Some actions require tenant authentication and prerequisites from their source modules.
- Placeholder workloads are intentionally visible in v1 for roadmap clarity.
