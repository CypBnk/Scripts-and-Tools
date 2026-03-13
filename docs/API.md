# Script API Documentation

## Overview

This repository is a script collection, not a REST service. This document describes the callable script and module interfaces in the repo.

## PowerShell Interfaces

### Invoke-SecurityGroupUsageDiscovery

Module path:

- src/Powershell/SecurityGroupUsage/SecurityGroupUsage.psm1

Public command:

- Invoke-SecurityGroupUsageDiscovery

Purpose:

- Discovers where Entra security groups are used across covered workloads and writes JSON, CSV, Markdown, and HTML outputs.

Key parameters:

- OutputPath: Root output directory. Runtime writes to OutputPath/TenantName/YYYY-MM-DD-HH_MM/files.
- SkipGraph: Skip Graph collection and generate baseline/report structure only.
- Scopes: Delegated scopes used during Graph collection.
- ReportMode: Static (default) or Dynamic HTML rendering.
- AuthMethod: WAM, DeviceCode, or ClientCredentials.
- TenantId, ClientId, ClientSecret: Used by ClientCredentials mode.
- PassThru: Returns in-memory objects in addition to writing files.

Output artifacts:

- security-group-usage.json
- security-group-usage-report.md
- security-group-usage-report.html
- security-group-usage-mapping.csv
- security-group-hygiene.csv
- security-group-orphan-candidates.csv
- security-group-duplicate-candidates.csv
- security-group-nested-map.csv (includes ParentGroupIds and ChildGroupIds)
- security-group-decision-matrix.csv

Current collector coverage:

- Entra ID role assignments (group principals)
- Enterprise Applications app role assignments (group principals)
- Conditional Access include/exclude group assignments
- Group-based licensing
- Intune app, compliance policy, and device configuration profile assignments
- Exchange Online mail-enabled security groups

Authentication and prerequisites:

- Uses Test-SguPrerequisites as fail-fast startup validation.
- Requires Microsoft.Graph.Authentication 2.34.0 or newer.

### Get-StaleDevices.ps1

Script path:

- src/Powershell/Intune-MDM-Management/Get-StaleDevices.ps1

Purpose:

- Lists stale Entra devices for a day range while excluding Autopilot devices.

Typical parameters:

- MinDays
- MaxDays
- CsvPath
- Scopes

### Invoke-EntraDeviceCleanup.ps1

Script path:

- src/Powershell/Intune-MDM-Management/Invoke-EntraDeviceCleanup.ps1

Purpose:

- Interactive workflow to review and optionally delete stale non-Autopilot devices.

### Delete RegKeys.ps1

Script path:

- src/Powershell/Intune-MDM-Management/Delete RegKeys.ps1

Purpose:

- Local Windows remediation for stale MDM enrollment artifacts and re-enrollment trigger.

## Python Interfaces

Python scripts currently in repository:

- src/Python/Generate Random Emails/Emailatrandom.py
- src/Python/Generate Random Emails/Emailatrandom_Updated.py
- src/Python/Generate Random Emails/import logging.py

These are standalone scripts (no package API surface).

## Error Handling Conventions

- PowerShell module/scripts use stop-on-error patterns and explicit validation.
- SecurityGroupUsage cmdlet throws clear prerequisite/auth errors before collector execution.
- Interactive scripts provide guidance prompts before high-impact actions.

## Related Docs

- docs/INSTALLATION.md
- docs/FAQ.md
- src/Powershell/SecurityGroupUsage/README.md
- src/Powershell/Intune-MDM-Management/README.md
