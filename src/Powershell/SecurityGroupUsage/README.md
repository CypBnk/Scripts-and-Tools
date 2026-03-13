# SecurityGroupUsage Module

This standalone PowerShell module helps discover and document where Entra security groups are used.

It is designed to:

- Use an internal workload and Graph endpoint catalog.
- Query Microsoft Graph for workload evidence where APIs are available.
- Emit documentation and mapping outputs for audits and handover.

## Public Command

- `Invoke-SecurityGroupUsageDiscovery`

## Quick Start

```powershell
Import-Module .\src\Powershell\SecurityGroupUsage\SecurityGroupUsage.psm1 -Force

Invoke-SecurityGroupUsageDiscovery `
  -OutputPath .\out\SecurityGroupUsage\latest
```

## Parameters

- `OutputPath` (optional): Output folder. Defaults to `out/SecurityGroupUsage/<timestamp>`.
- `SkipGraph` (optional switch): Build catalog and report without Graph collection.
- `Scopes` (optional): Graph delegated scopes for collection.
- `PassThru` (optional switch): Returns in-memory objects.

## Output Files

- `security-group-usage.json`
- `security-group-usage-report.md`
- `security-group-usage-mapping.csv`
- `security-group-hygiene.csv`
- `security-group-orphan-candidates.csv`
- `security-group-duplicate-candidates.csv`
- `security-group-nested-map.csv`
- `security-group-decision-matrix.csv`
- `security-group-usage-report.html`

## Current Collector Coverage

Implemented Graph collectors:

- Entra ID role assignments where group principals are present
- Enterprise Applications app role assignments where group principals are present
- Conditional Access policy group include/exclude assignments
- Group-based licensing via groups with assigned licenses
- Intune app, device compliance policy, and device configuration profile group assignments
- Exchange Online mail-enabled security groups
- Security group hygiene enrichment (created date, cloud/on-prem classification, owner/member counts, nested flags, duplicate indicators)
- Decision matrix enrichment (Keep, Review, RemoveCandidate)

Reference-only or partial coverage (current baseline):

- Purview Insider Risk, SharePoint, Teams, and Defender areas where workload-specific APIs/admin endpoints require manual validation

## Required Graph Scopes

- `Directory.Read.All`
- `Group.Read.All`
- `Policy.Read.All`
- `RoleManagement.Read.Directory`
- `DeviceManagementApps.Read.All`
- `DeviceManagementConfiguration.Read.All`
- `Application.Read.All`
