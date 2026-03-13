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

## Detection Logic and Known False-Positive Scenarios

### Duplicate Detection

Duplicates are flagged using two independent rules:

| Rule              | Logic                                                                                    | Known False Positives                                                                                                                                                  |
| ----------------- | ---------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `DuplicateByName` | Normalized display name (whitespace collapsed, `.ToLowerInvariant()`) matches ≥ 2 groups | Groups with intentionally identical names for different purposes (e.g. `Pilot-Users` for separate tenant scopes); abbreviation-expanded equivalents will **not** match |
| `DuplicateByMail` | Lowercased `mail` attribute matches ≥ 2 groups                                           | Rare — should not occur in healthy tenants; possible if a mail attribute was manually migrated and appears on a cloud-only group                                       |

**Recommended review step:** For every `DuplicateByName` pair, compare `GroupId`, `CreatedDateTime`, `IsCloudOnly`, `MemberCount`, and workload evidence before acting. Name equality alone is not sufficient justification for deletion.

### Orphan / PotentiallyOrphaned Detection

A group is flagged `PotentiallyOrphaned = true` only when **all** of the following are true simultaneously:

- `NoOwners` — zero owner objects returned from Graph
- `NoMembers` — zero member objects returned from Graph
- `NoUsageEvidence` — no evidence row in any workload collector
- `ParentGroupCount = 0` — not nested inside another group
- `ChildGroupCount = 0` — contains no nested child groups

| Condition         | Known False Positive Risk                                                                                                                                                                                |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `NoUsageEvidence` | Workloads outside current collector scope (Defender RBAC, SharePoint site permissions, Teams policies) will not produce evidence — a group actively used there still appears as `NoUsageEvidence = true` |
| `NoMembers`       | Dynamic membership groups return zero members via the `members` endpoint; these groups may be fully active                                                                                               |
| `NoOwners`        | Service-account-owned groups where the owner object is a service principal (not a user) may report zero owners                                                                                           |

**Conservative rule:** The `RemoveCandidate` classification requires all five conditions to be true. Groups with any nesting or partial governance signals are classified `Review`, not `RemoveCandidate`.
