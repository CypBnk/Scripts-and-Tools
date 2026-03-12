# Installation Guide

This guide covers setup for all script types in this repository.

## Prerequisites

- Git
- Text editor or IDE (VS Code, PowerShell ISE, etc.)
- Depending on script type, install one or more of the following

## Step 1: Clone the Repository

```bash
git clone https://github.com/username/PowerScripts.git
cd PowerScripts
```

## Step 2: Install Runtime Environments

### PowerShell Setup (Windows)

```powershell
# Check PowerShell version (requires 5.0+)
$PSVersionTable.PSVersion

# Set execution policy to allow scripts
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Install Microsoft Graph PowerShell SDK (required for Entra/Intune scripts)
Install-Module Microsoft.Graph -Scope CurrentUser
```

### Microsoft Graph Permissions for Stale Device Reporting

The `src/Powershell/Get-StaleDevices.ps1` script requires Microsoft Graph delegated permissions:

- `Device.Read.All`
- `DeviceManagementServiceConfig.Read.All`

When prompted during `Connect-MgGraph`, grant consent for these scopes.

The `src/Powershell/Invoke-EntraDeviceCleanup.ps1` script uses:

- Read-only mode: `Device.Read.All`, `DeviceManagementServiceConfig.Read.All`
- Read+write mode: `Device.Read.All`, `Device.ReadWrite.All`, `DeviceManagementServiceConfig.Read.All`

### Microsoft Graph Permissions for Security Group Usage Discovery

The `src/Powershell/SecurityGroupUsage/SecurityGroupUsage.psm1` module uses delegated scopes:

- `Directory.Read.All`
- `Group.Read.All`
- `Policy.Read.All`
- `RoleManagement.Read.Directory`
- `DeviceManagementApps.Read.All`
- `Application.Read.All`

Grant these scopes when prompted by `Connect-MgGraph`.

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

### Node.js/JavaScript Setup

```bash
# Check Node.js installation
node --version  # Requires 12.0 or higher

# Install dependencies
cd JS/
npm install
# or
yarn install
```

### Bash/Shell Setup

```bash
# Check Bash version (requires 4.0+)
bash --version

# Make scripts executable
chmod +x Shell_BASH/*.sh
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
```

### Running Python Scripts

```bash
# From the repository root
python src/Python/script_name.py

# With arguments
python src/Python/script_name.py --argument value
```

## Getting Help

- Check the [FAQ](FAQ.md)
- Review [GitHub Issues](../../issues)
- See [Contributing Guidelines](../CONTRIBUTING.md)
