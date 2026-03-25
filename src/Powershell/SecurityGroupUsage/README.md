# SecurityGroupUsage Module (Zip-Only Quick Start)

This guide is written for users who downloaded a ZIP that contains only this folder (`SecurityGroupUsage`).

## What this module does

`SecurityGroupUsage` discovers where Entra security groups are used and writes audit-friendly outputs (JSON, CSV, Markdown, HTML).

## Folder layout expected after unzip

```text
SecurityGroupUsage/
  SecurityGroupUsage.psm1
  README.md <--- This File
  Private/
  Public/
```

## Prerequisites

- PowerShell 7.0 or newer
- Microsoft Graph PowerShell SDK
- `Microsoft.Graph.Authentication` version `2.34.0` or newer

Install/update prerequisites:

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force
```

## Run from the extracted folder

1. Open PowerShell 7.
2. Go to the extracted folder root (the folder that contains `SecurityGroupUsage.psm1`).

Example:

```powershell
Set-Location C:\Path\To\SecurityGroupUsage
```

3. Import the module:

```powershell
Import-Module .\SecurityGroupUsage.psm1 -Force
```

## First run (no authentication smoke test)

Use this to confirm the module loads and output generation works without Graph sign-in:

```powershell
Invoke-SecurityGroupUsageDiscovery `
  -SkipGraph `
  -OutputPath .\out\SecurityGroupUsage\smoke-test
```

## Full run (with Microsoft Graph)

Default interactive run:

```powershell
Invoke-SecurityGroupUsageDiscovery `
  -OutputPath .\out\SecurityGroupUsage
```

You can optionally choose auth explicitly:

```powershell
Invoke-SecurityGroupUsageDiscovery `
  -AuthMethod DeviceCode `
  -OutputPath .\out\SecurityGroupUsage
```

Supported auth modes:

- `WAM`
- `DeviceCode`
- `ClientCredentials`

## Client credentials example

```powershell
$secret = Read-Host "Client Secret" -AsSecureString

Invoke-SecurityGroupUsageDiscovery `
  -AuthMethod ClientCredentials `
  -TenantId "<tenant-id>" `
  -ClientId "<app-client-id>" `
  -ClientSecret $secret `
  -OutputPath .\out\SecurityGroupUsage
```

## Output location and files

By default, results are written to:

`<OutputPath>/<TenantName>/YYYY-MM-DD-HH_MM/`

Typical files produced:

- `security-group-usage.json`
- `security-group-usage-report.md`
- `security-group-usage-report.html`
- `security-group-usage-mapping.csv`
- `security-group-hygiene.csv`
- `security-group-orphan-candidates.csv`
- `security-group-duplicate-candidates.csv`
- `security-group-nested-map.csv`
- `security-group-decision-matrix.csv`

## Common parameters

- `-OutputPath` (optional): Output root folder (default: `out/SecurityGroupUsage`)
- `-SkipGraph` (switch): Build catalog/report without Graph collection
- `-Scopes` (optional): Override delegated Graph scopes
- `-PassThru` (switch): Return in-memory objects
- `-ReportMode` (optional): `Static` (default) or `Dynamic`
- `-AuthMethod` (optional): `WAM`, `DeviceCode`, `ClientCredentials`
- `-TenantId`, `-ClientId`, `-ClientSecret`: For `ClientCredentials`

## Troubleshooting

### Module import fails

- Confirm you are in the folder that contains `SecurityGroupUsage.psm1`.
- Run `Get-Module -ListAvailable Microsoft.Graph.Authentication` and verify version is `2.34.0+`.

### Dynamic HTML mode fails

Install `PSWriteHTML` if using `-ReportMode Dynamic`:

```powershell
Install-Module PSWriteHTML -Scope CurrentUser
```

### Graph auth prompts or permission issues

The module requires Graph read scopes such as:

- `Directory.Read.All`
- `Group.Read.All`
- `Policy.Read.All`
- `RoleManagement.Read.Directory`
- `DeviceManagementApps.Read.All`
- `DeviceManagementConfiguration.Read.All`
- `Application.Read.All`
