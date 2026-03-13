# PowerScripts Collection

A comprehensive collection of automation and utility scripts across multiple scripting languages.

## Overview

This repository contains a curated collection of scripts for system administration, automation, deployment, and utility purposes. Scripts are organized by language: PowerShell, Python, Shell/Bash, and JavaScript.

## Features

- **PowerShell Scripts**: Windows system administration and automation
- **Python Scripts**: Cross-platform utilities and data processing
- **Shell/Bash Scripts**: Linux/Unix system utilities and automation
- **JavaScript Scripts**: Web automation and Node.js utilities

## Repository Structure

```text
.
├── src/
│   ├── Powershell/      # PowerShell scripts for Windows administration
│   └── Python/          # Python utilities and data processing scripts
├── tests/               # Automated tests
└── docs/                # Documentation
```

## Installation & Setup

Each script type has different requirements. See the [Installation Guide](docs/INSTALLATION.md) for detailed setup instructions.

### Quick Start

**PowerShell:**

```powershell
# Run a PowerShell script
.\src\Powershell\script-name.ps1
```

**Python:**

```bash
python src/Python/script_name.py
```

### Entra Device Cleanup Workflow

Use the interactive Entra cleanup script to authenticate, list devices, apply stale-device filters, and optionally delete non-Autopilot stale devices.

```powershell
.\src\Powershell\Invoke-EntraDeviceCleanup.ps1
```

The filter step supports predefined thresholds (30/90/365 days) and a custom day threshold.

### Security Group Usage Discovery

Use the standalone module with an internal workload/endpoint catalog and enrich findings from Microsoft Graph where available.

```powershell
Import-Module .\src\Powershell\SecurityGroupUsage\SecurityGroupUsage.psm1 -Force

Invoke-SecurityGroupUsageDiscovery `
    -OutputPath .\out\SecurityGroupUsage
```

Output files are written under:

`<OutputPath>\<TenantName>\YYYY-MM-DD-HH_MM\`

Authentication modes:

- Interactive WAM
- Device code flow
- Client credentials (`TenantId`, `ClientId`, `ClientSecret`)

Default output artifacts:

- Console summary
- JSON dataset
- Markdown report
- CSV mapping export
- CSV hygiene export
- CSV orphan-candidates export
- CSV duplicate-candidates export
- CSV nested-map export
- CSV decision-matrix export
- HTML report

## Requirements

**PowerShell:**

- Windows 7 or higher
- PowerShell 5.0 or higher
- Administrator privileges (for some scripts)

**Python:**

- Python 3.8 or higher
- pip package manager

Notes:

- Microsoft Graph PowerShell SDK is required for Entra/Intune PowerShell scripts.
- Required delegated scopes depend on execution mode (read-only or read+write).
- Security Group Usage Discovery uses Graph scopes: `Directory.Read.All`, `Group.Read.All`, `Policy.Read.All`, `RoleManagement.Read.Directory`, `DeviceManagementApps.Read.All`, `DeviceManagementConfiguration.Read.All`, and `Application.Read.All`.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the [MIT License](LICENSE).

## Support

For support, please open an [issue](../../issues) or contact the maintainers.

## Changelog

See [CHANGELOG.md](docs/CHANGELOG.md) for version history.

## Authors

- Your Name (@username)

## Acknowledgments

- Credit contributors and dependencies here
