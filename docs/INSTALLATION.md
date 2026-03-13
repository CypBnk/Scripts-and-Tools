# Installation Guide

This guide covers setup for the script types currently present in this repository.

## Prerequisites

- Git
- Text editor or IDE (VS Code, PowerShell ISE, etc.)
- Depending on script type, install one or more of the following

## Step 1: Clone the Repository

```bash
git clone https://github.com/CypBnk/Scripts-and-Tools.git
cd Scripts-and-Tools
```

## Step 2: Install Runtime Environments

### PowerShell Setup (Windows)

```powershell
# Check PowerShell version
$PSVersionTable.PSVersion

# Set execution policy to allow scripts
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Install Microsoft Graph PowerShell SDK (required for Entra/Intune scripts)
Install-Module Microsoft.Graph -Scope CurrentUser
```

Version guidance:

- Intune-MDM-Management scripts: Windows PowerShell 5.1 or PowerShell 7+
- SecurityGroupUsage module: PowerShell 7+ (with prerequisite validation at startup)

### Microsoft Graph Permissions for Stale Device Reporting

The `src/Powershell/Intune-MDM-Management/Get-StaleDevices.ps1` script requires Microsoft Graph delegated permissions:

- `Device.Read.All`
- `DeviceManagementServiceConfig.Read.All`

When prompted during `Connect-MgGraph`, grant consent for these scopes.

The `src/Powershell/Intune-MDM-Management/Invoke-EntraDeviceCleanup.ps1` script uses:

- Read-only mode: `Device.Read.All`, `DeviceManagementServiceConfig.Read.All`
- Read+write mode: `Device.Read.All`, `Device.ReadWrite.All`, `DeviceManagementServiceConfig.Read.All`

### Microsoft Graph Permissions for Security Group Usage Discovery

The `src/Powershell/SecurityGroupUsage/SecurityGroupUsage.psm1` module uses delegated scopes:

- `Directory.Read.All`
- `Group.Read.All`
- `Policy.Read.All`
- `RoleManagement.Read.Directory`
- `DeviceManagementApps.Read.All`
- `DeviceManagementConfiguration.Read.All`
- `Application.Read.All`

Grant these scopes when prompted by `Connect-MgGraph`.

SecurityGroupUsage runtime prerequisites:

- PowerShell 7.0 or newer
- Microsoft Graph PowerShell SDK installed (`Install-Module Microsoft.Graph -Scope CurrentUser`)
- `Microsoft.Graph.Authentication` 2.34.0 or newer

### Python Setup

```bash
# Check Python installation
python --version  # Requires 3.8 or higher

# Create virtual environment (recommended)
python -m venv venv

# Activate virtual environment
# On Windows:
venv\Scripts\activate
# On macOS/Linux:
source venv/bin/activate

# Install dependencies
if [ -f requirements.txt ]; then pip install -r requirements.txt; fi
```

## Step 3: Running Scripts

### Running PowerShell Scripts

```powershell
# Execute a PowerShell script
.\src\Powershell\script-name.ps1

# With parameters
.\src\Powershell\script-name.ps1 -Param1 "value1" -Param2 "value2"

# Interactive Entra cleanup workflow
.\src\Powershell\Invoke-EntraDeviceCleanup.ps1

# Security group usage discovery
Import-Module .\src\Powershell\SecurityGroupUsage\SecurityGroupUsage.psm1 -Force
Invoke-SecurityGroupUsageDiscovery

# Optional: explicit authentication mode
Invoke-SecurityGroupUsageDiscovery -AuthMethod DeviceCode

# Optional: app-only auth
# $secret = ConvertTo-SecureString "<client-secret>" -AsPlainText -Force
# Invoke-SecurityGroupUsageDiscovery -AuthMethod ClientCredentials -TenantId "<tenant-id>" -ClientId "<client-id>" -ClientSecret $secret
```

SecurityGroupUsage output layout:

`<OutputPath>\<TenantName>\YYYY-MM-DD-HH_MM\<files>`

Example:

`out\SecurityGroupUsage\Contoso Ltd\2026-03-13-21_42\security-group-usage.json`

### Running Python Scripts

```bash
# From the repository root (examples)
python "src/Python/Generate Random Emails/Emailatrandom.py"
python "src/Python/Generate Random Emails/Emailatrandom_Updated.py"
```

## Repository Scope Note

Current source layout includes:

- PowerShell scripts/modules under src/Powershell
- Python scripts under src/Python

If additional language folders are added later, extend this guide with matching setup steps.

## Getting Help

- Check the [FAQ](FAQ.md)
- Review [GitHub Issues](../../issues)
- See [Contributing Guidelines](../CONTRIBUTING.md)
