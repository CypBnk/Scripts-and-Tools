# Frequently Asked Questions (FAQ)

## General Questions

### What is this project?

This repository contains practical automation scripts, currently focused on PowerShell administration workflows and utility Python scripts.

### Who maintains this project?

Maintainer and contributor details are tracked in the repository history. Contribution workflow is documented in [CONTRIBUTING.md](../CONTRIBUTING.md).

### Is this project still actively maintained?

Yes, we're actively developing and maintaining this project. Check the [CHANGELOG.md](CHANGELOG.md) for recent updates.

## Installation & Setup

### How do I install this project?

See the [Installation Guide](INSTALLATION.md) for detailed instructions.

### Do I need any special permissions?

Most features require only standard user permissions. Some advanced features may require administrator access.

### Can I use this on [specific OS/platform]?

PowerShell scripts in this repository are primarily Windows-oriented (especially Intune/Entra workflows). Some script logic can run cross-platform with PowerShell 7+, but Graph auth mode availability and local remediation scripts can be platform-specific.

## Usage Questions

### Where can I find usage examples?

Check the [README.md](../README.md) and script-specific help output.

### How do I run Security Group Usage Discovery?

Use the module command:

```powershell
Import-Module .\src\Powershell\SecurityGroupUsage\SecurityGroupUsage.psm1 -Force
Invoke-SecurityGroupUsageDiscovery -OutputPath .\out\SecurityGroupUsage
```

Outputs are written under:

- OutputPath/TenantName/YYYY-MM-DD-HH_MM/files

Example:

- out/SecurityGroupUsage/Contoso Ltd/2026-03-13-21_42/security-group-usage.json

Quick validation without Graph authentication:

```powershell
Import-Module .\src\Powershell\SecurityGroupUsage\SecurityGroupUsage.psm1 -Force
Invoke-SecurityGroupUsageDiscovery -SkipGraph -OutputPath .\out\SecurityGroupUsage\smoke-test
```

### Which authentication methods are supported in Security Group Usage Discovery?

- WAM
- DeviceCode
- ClientCredentials

If AuthMethod is omitted, the command prompts interactively.

### Why does Security Group Usage fail immediately before running collectors?

The module runs prerequisite validation first and fails fast when requirements are missing, such as:

- PowerShell 7+
- Microsoft Graph SDK not installed
- Microsoft.Graph.Authentication version below 2.34.0
- Required Graph commands unavailable after import

### How do I find stale Entra devices and exclude Autopilot devices?

Use `src/Powershell/Intune-MDM-Management/Get-StaleDevices.ps1`.

Example:

```powershell
.\src\Powershell\Intune-MDM-Management\Get-StaleDevices.ps1 -MinDays 60 -MaxDays 3650 -Verbose
```

Optional CSV export:

```powershell
.\src\Powershell\Intune-MDM-Management\Get-StaleDevices.ps1 -MinDays 90 -MaxDays 365 -CsvPath .\stale-devices.csv
```

### How do I run the interactive Entra cleanup workflow?

Use `src/Powershell/Intune-MDM-Management/Invoke-EntraDeviceCleanup.ps1`.

Example:

```powershell
.\src\Powershell\Intune-MDM-Management\Invoke-EntraDeviceCleanup.ps1
```

The script guides you through authentication, listing, filtering (including a custom threshold), and optional deletion in read+write mode.

### How do I report a bug?

Please open an [issue](../../issues) with a clear description and steps to reproduce.

### Can I request a feature?

Absolutely! Please use [GitHub Discussions](../../discussions) or open a [feature request issue](../../issues).

## Troubleshooting

### Something isn't working. What should I do?

1. Check the [Installation Guide](INSTALLATION.md) troubleshooting section
2. Search existing [issues](../../issues)
3. Review the [API Documentation](API.md)
4. Open a new issue if you can't find a solution

### I found a security vulnerability. What should I do?

Please follow [SECURITY.md](../SECURITY.md) and avoid posting exploit details in public issues.

## Contributing

### How can I contribute?

See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines on code contributions, bug reports, and feature suggestions.

### What's the code style?

For PowerShell, follow repository and module conventions (parameter validation, clear help text, and safe defaults). For Python, use readable PEP 8-style formatting.

## License & Legal

### What license is this project under?

This project is licensed under the MIT License. See [LICENSE](../LICENSE) for details.

### Can I use this commercially?

Yes! The MIT License permits commercial use.

## Still Have Questions?

- Join our [Discussions](../../discussions)
- Check related documentation files
- Open an [issue](../../issues) if you think you've found a bug
