# SecurityGroupUsage v0.5.0-beta.1

## Release Notice

- Version: `v0.5.0-beta.1`
- Release file: `SecurityGroupUsage.zip`
- SHA256: `F08CD69FBDC5A1FDBE3531B67835D90ED390C580E596113AAAFA226A69E152D7`

## Feature Highlights

- Discovers where Entra security groups are used across supported Microsoft workloads.
- Builds a workload catalog and evidence matrix for audit and handover scenarios.
- Supports `WAM`, `DeviceCode`, and `ClientCredentials` authentication modes.
- Supports static report generation by default and optional dynamic HTML rendering.
- Provides `-SkipGraph` mode for quick smoke tests and offline catalog/report generation.

## Current Collector Coverage

- Entra role assignments (group principals)
- Enterprise Applications app role assignments (group principals)
- Conditional Access include/exclude group assignments
- Group-based licensing evidence
- Intune app and policy assignment evidence
- Exchange Online mail-enabled security group evidence
- Group hygiene enrichment (owners, members, cloud/on-prem, nested and duplicate indicators)
- Decision matrix classification (`Keep`, `Review`, `RemoveCandidate`)

## Output Package Contents

Expected output files produced by discovery include:

- `security-group-usage.json`
- `security-group-usage-report.md`
- `security-group-usage-report.html`
- `security-group-usage-mapping.csv`
- `security-group-hygiene.csv`
- `security-group-orphan-candidates.csv`
- `security-group-duplicate-candidates.csv`
- `security-group-nested-map.csv`
- `security-group-decision-matrix.csv`

## Notes

- Some workloads still require manual validation where APIs are limited or not available.
- Detection output is intentionally conservative to reduce accidental deletion decisions.

## Integrity Verification (PowerShell)

```powershell
Get-FileHash .\SecurityGroupUsage.zip -Algorithm SHA256
```

Expected hash:

`F08CD69FBDC5A1FDBE3531B67835D90ED390C580E596113AAAFA226A69E152D7`
