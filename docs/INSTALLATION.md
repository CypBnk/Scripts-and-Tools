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
```

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
.\Powershell\script-name.ps1

# With parameters
.\Powershell\script-name.ps1 -Param1 "value1" -Param2 "value2"
```

### Running Python Scripts

```bash
# From the repository root
python Python/script_name.py

# With arguments
python Python/script_name.py --argument value
```

### Running Bash/Shell Scripts

```bash
# Make sure script is executable first
chmod +x Shell_BASH/script-name.sh

# Execute the script
bash Shell_BASH/script-name.sh

# Or directly with shebang
./Shell_BASH/script-name.sh
```

### Running JavaScript Scripts

```bash
# From the JS directory
node script-name.js

# Or from the repository root
node JS/script-name.js
```

## Getting Help

- Check the [FAQ](FAQ.md)
- Review [GitHub Issues](../../issues)
- See [Contributing Guidelines](../CONTRIBUTING.md)
