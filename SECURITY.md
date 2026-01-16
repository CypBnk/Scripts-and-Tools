# Security Best Practices

This document outlines security best practices for using scripts in this repository.

## Credential Management

### ❌ NEVER DO THIS

```powershell
# DO NOT hardcode passwords in scripts
$password = "MySecurePassword123"
$creds = New-Object System.Management.Automation.PSCredential -ArgumentList $user, $password
```

```python
# DO NOT hardcode API keys or tokens
api_key = "sk-1234567890abcdef"
```

### ✅ DO THIS INSTEAD

**PowerShell:**

```powershell
# Use Get-Credential for interactive credential input
$creds = Get-Credential

# Or use Windows Credential Manager
$creds = Get-StoredCredential -Target "MyService"

# Or use Azure Key Vault for sensitive data
$secret = Get-AzKeyVaultSecret -VaultName "MyVault" -Name "MySecret"
```

**Python:**

```python
import os
from getpass import getpass

# Use environment variables for sensitive data
api_key = os.environ.get('API_KEY')

# Or prompt user for input
password = getpass("Enter your password: ")

# For CI/CD, use secure secret management (GitHub Secrets, Azure Key Vault, etc.)
```

**Node.js:**

```javascript
// Use environment variables
const apiKey = process.env.API_KEY;

// Use dotenv for local development
require("dotenv").config();
```

## Sensitive Data

### Remove Before Committing

Check your scripts for:

- **Passwords and API keys** - Replace with placeholders (e.g., `YOUR_API_KEY`, `yourdomain.com`)
- **Personal email addresses** - Replace with examples (e.g., `user@example.com`)
- **Internal domain names** - Replace with placeholders (e.g., `yourdomain.com`)
- **Server names and IPs** - Replace with examples
- **Database connection strings** - Never commit actual credentials
- **OAuth tokens and secrets**
- **SSH keys and certificates**
- **Database names and usernames**

### Search for Sensitive Data

Before committing, search for common patterns:

```bash
# Search for common secret patterns
grep -r "password\|api.?key\|secret\|token" --include="*.ps1" --include="*.py" --include="*.js" .

# Search for email addresses (review for sensitive ones)
grep -r "@[a-zA-Z0-9.-]\+\.[a-zA-Z0-9]\+" --include="*.ps1" --include="*.py" .

# Search for connection strings
grep -r "Server=\|server=\|Host=\|host=" --include="*.ps1" --include="*.py" .
```

## Environment Variables

Use `.env` files for local development secrets (add to `.gitignore`):

```bash
# .env (DO NOT COMMIT)
API_KEY=your_actual_key
DATABASE_URL=your_actual_connection_string
DOMAIN=yourdomain.com
```

```python
# Load from .env in Python
from dotenv import load_dotenv
import os

load_dotenv()
api_key = os.getenv('API_KEY')
```

## Git Configuration

### Prevent Accidental Commits

Add secrets filter to `.gitconfig`:

```bash
# Configure git to check for secrets
git config --global core.hooksPath /path/to/hooks

# Or use git-secrets tool
brew install git-secrets  # macOS
git secrets --install
```

### Review Before Committing

```bash
# Check diff before committing
git diff --staged

# Scan for secrets in staged files
git secrets --scan
```

## File Permissions

### PowerShell Scripts

```powershell
# Restrict script access on sensitive systems
icacls "C:\Scripts\sensitive.ps1" /grant:r "%USERNAME%:F" /inheritance:r
```

### Unix/Linux Scripts

```bash
# Restrict file permissions to owner only
chmod 700 sensitive-script.sh

# For scripts that should be executable by group
chmod 750 script.sh
```

## Audit and Logging

### PowerShell

```powershell
# Enable script block logging
Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name "EnableScriptBlockLogging" -Value 1

# Enable PowerShell logging
Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\PowerShell\Transcription" -Name "EnableTranscripting" -Value 1
```

### General Best Practices

- Use a centralized logging system
- Monitor for suspicious activity
- Regularly audit script usage
- Implement proper access controls
- Use multi-factor authentication (MFA) where possible

## Incident Response

If you accidentally commit sensitive data:

1. **Immediately rotate credentials** - Change passwords, API keys, etc.
2. **Remove from history** - Use `git filter-branch` or `git-filter-repo`
3. **Alert team members** - Notify about potential exposure
4. **Review commit access logs** - Check who had access to the secret

```bash
# Remove a file from all history
git filter-repo --invert-paths --path path/to/secret-file

# Or use git filter-branch
git filter-branch --tree-filter 'rm -f path/to/secret-file' HEAD
```

## Additional Resources

- [OWASP Secrets Management](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
- [GitHub Secret Scanning](https://docs.github.com/en/code-security/secret-scanning)
- [Azure Key Vault](https://docs.microsoft.com/en-us/azure/key-vault/)
- [AWS Secrets Manager](https://aws.amazon.com/secrets-manager/)

## Questions?

If you find sensitive data in this repository, please report it responsibly:

- For GitHub repos: Use the private vulnerability disclosure feature
- For internal repos: Contact the security team
- Do not publicly disclose sensitive information
