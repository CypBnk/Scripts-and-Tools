# ExchangeFixer Release Notes

## Version 1.0.0-Beta1

**Release Date:** April 7, 2026

### Overview

ExchangeFixer v1.0.0-Beta1 introduces the core functionality for synchronizing ArchiveGUID values from Exchange Online to on-premises Active Directory and Exchange Server. This beta release includes comprehensive features for managing hybrid Exchange environments and validating mailbox configurations.

---

## 🎯 New Features

### 1. ArchiveGUID Synchronization

- **Primary Cmdlet:** `Sync-ArchiveGuidFromEXO`
- Retrieves all Exchange Online mailboxes with enabled archives
- Automatically matches mailboxes to on-premises counterparts by SAM/UPN/SMTP address
- Writes ArchiveGUID to both on-premises AD (`msExchArchiveGUID` attribute) and Exchange Server
- Generates detailed CSV reports with per-mailbox sync results
- Graceful error handling: continues on failures and reports all issues

### 2. Explicit Domain Controller Selection

- **Parameter:** `-ADDomainController` (optional)
- Specify which domain controller to use for Active Directory operations
- Automatic PDC emulator discovery when not specified
- Domain controller used consistently across all AD operations (Get-ADUser, Set-ADUser)
- Useful for multi-site environments or when DC selection is critical

### 3. Single-User Test Mode

- **Parameter:** `-TestUser` (optional)
- Test sync process for a single user before running full organization-wide sync
- End-to-end validation: retrieves from EXO, writes to AD and on-premises Exchange
- Console output with color-coded results (Success/Failed/Warning)
- No CSV report generated for test runs (immediate console feedback)
- Supports user identification by SAM account name, UPN, or email address

### 4. Interactive Menu System

- **Triggered:** When `Sync-ArchiveGuidFromEXO` is invoked without parameters
- **Menu Options:**
  1. Full synchronization (all EXO mailboxes with archives)
  2. Single-user test (end-to-end validation for one user)
  3. Exit
- Dynamic prompts for required inputs (Exchange server, optional DC)
- Clean error handling with user guidance

### 5. Optimized Testing Architecture

- Prerequisites validation runs **once** on module import
- Result cached in module scope for reuse during sync operations
- Eliminates redundant prerequisite checks on every cmdlet invocation
- Improves performance for repeated operations within same PowerShell session
- User can still control flow based on cached result

---

## 📋 Prerequisites

### **Required Software**

- PowerShell 5.1 or later
- ExchangeOnlineManagement module v2.0.5 or later
- Active Directory module (RSAT-AD-PowerShell on Windows clients or Server feature on domain controllers)
- PowerShell Remoting enabled (for on-premises Exchange communication)

### **Required Permissions**

- Exchange Online Administrator role (Exchange Admin Center)
- Exchange Server Administrator role (on-premises)
- Active Directory Domain Administrator or equivalent permissions
- Network connectivity to on-premises Exchange Server (port 5985 WinRM)

---

## 🚀 Quick Start

### Basic Usage: Full Organization Sync

```powershell
# Import module
Import-Module ExchangeFixer

# Run interactive menu
Sync-ArchiveGuidFromEXO

# Or invoke directly
Sync-ArchiveGuidFromEXO -OnPremExchangeServer "exchange.contoso.com"
```

### Advanced: With Explicit Domain Controller

```powershell
Sync-ArchiveGuidFromEXO `
  -OnPremExchangeServer "exchange.contoso.com" `
  -ADDomainController "dc1.contoso.com"
```

### Single-User Test Mode

```powershell
# Test single user
Sync-ArchiveGuidFromEXO `
  -OnPremExchangeServer "exchange.contoso.com" `
  -TestUser "jsmith"

# Test with verbose output
Sync-ArchiveGuidFromEXO `
  -OnPremExchangeServer "exchange.contoso.com" `
  -TestUser "jsmith@contoso.com" `
  -Verbose

# Preview mode (WhatIf)
Sync-ArchiveGuidFromEXO `
  -OnPremExchangeServer "exchange.contoso.com" `
  -TestUser "jsmith" `
  -WhatIf
```

### Full Command Examples

```powershell
# With custom output path
Sync-ArchiveGuidFromEXO `
  -OnPremExchangeServer "exchange.contoso.com" `
  -OutputPath "C:\Reports\ArchiveSync_$(Get-Date -Format 'yyyyMMdd').csv"

# With alternate credentials
Sync-ArchiveGuidFromEXO `
  -OnPremExchangeServer "exchange.contoso.com" `
  -Credential (Get-Credential)

# With all options
Sync-ArchiveGuidFromEXO `
  -OnPremExchangeServer "exchange.contoso.com" `
  -ADDomainController "dc1.contoso.com" `
  -OutputPath "C:\Reports\sync.csv" `
  -Credential (Get-Credential) `
  -Verbose
```

---

## 📊 Output

### Full Sync Output

- **Format:** CSV report with the following columns:
  - `Mailbox` - User mailbox identifier
  - `Status` - Success, Failed, or Skipped
  - `Message` - Detailed result message
  - `Timestamp` - Sync operation timestamp
- **Location:** Specified path or `.\ArchiveGuidSync_YYYYMMdd_HHmmss.csv`

### Single-User Test Output

- **Format:** Console table with color-coded status
- **Colors:**
  - Green: Successful operations
  - Yellow: Warnings or partial success
  - Red: Failed operations
- **Example:**
  ```
  === Test User Validation Results ===
  User: jsmith@contoso.com
    Status: Success
    Message: ArchiveGUID synced successfully (AD and Exchange updated)
  ```

---

## ✅ Supported Operations

| Operation                  | Full Sync | Test Mode | WhatIf  |
| -------------------------- | :-------: | :-------: | :-----: |
| EXO mailbox retrieval      |     ✓     |     ✓     |    ✓    |
| On-premises mailbox lookup |     ✓     |     ✓     |    ✓    |
| AD ArchiveGUID write       |     ✓     |     ✓     | Preview |
| Exchange ArchiveGUID write |     ✓     |     ✓     | Preview |
| CSV report generation      |     ✓     |     ✗     |    ✓    |
| Console result display     |  Summary  | Detailed  |    ✓    |

---

## 🔄 Parameter Reference

### Sync-ArchiveGuidFromEXO

| Parameter              | Type         | Default        | Description                                         |
| ---------------------- | ------------ | -------------- | --------------------------------------------------- |
| `OnPremExchangeServer` | string       | Optional       | FQDN or NetBIOS name of on-premises Exchange Server |
| `ADDomainController`   | string       | Auto-discover  | Specific domain controller FQDN for AD operations   |
| `TestUser`             | string       | —              | Single user SAM/UPN for end-to-end validation       |
| `OutputPath`           | string       | Auto-generated | Path for CSV report file                            |
| `Credential`           | PSCredential | Current user   | Alternate credentials for on-premises Exchange      |
| `WhatIf`               | switch       | —              | Preview mode showing planned changes                |
| `Verbose`              | switch       | —              | Detailed operation logging                          |
| `Confirm`              | switch       | —              | Prompt before executing sync                        |

---

## 🐛 Known Limitations (Beta)

1. **Single Domain Only** - Currently designed for single Active Directory domain environments
2. **Mailbox Matching** - Matching priority: SAM account → UPN → Email address. Custom matching rules not yet supported
3. **Error Reporting** - Some Exchange Server errors may not have detailed descriptions
4. **Large Deployments** - Performance not optimized for >100K mailboxes on first sync
5. **Archive Status** - Does not verify if EXO archive is actually enabled before processing

---

## 🔒 Security Considerations

- **Credentials:** Supports Windows authentication (Kerberos) to on-premises Exchange; no credential storage
- **PowerShell Remoting:** Communicates with on-premises Exchange via WinRM (port 5985)
- **AD Modifications:** Writes only to `msExchArchiveGUID` attribute; no other AD attributes modified
- **Audit Trail:** All operations logged to CSV for compliance review
- **WhatIf Mode:** Always available for preview before committing changes

---

## 📝 Breaking Changes

**None** - First release (no previous version to break from)

---

## 🔧 Troubleshooting

### "ActiveDirectory module NOT installed"

**Solution:** Install RSAT-AD-PowerShell on Windows or RSAT-AD-PowerShell feature on Server

```powershell
# Windows 10/11
Add-WindowsCapability -Online -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0"

# Windows Server
Install-WindowsFeature RSAT-AD-PowerShell
```

### "PowerShell Remoting may not be fully configured"

**Solution:** Enable PowerShell Remoting

```powershell
Enable-PSRemoting -Force
```

### "Cannot reach Exchange server on port 5985"

**Solution:** Verify on-premises Exchange server connectivity

```powershell
Test-NetConnection -ComputerName <ExchangeServer> -Port 5985
```

### "No matching on-premises mailbox found"

**Solution:** Ensure mailbox exists on-premises and SAM/UPN/Email matches EXO

```powershell
# Check on-premises mailbox
Get-Mailbox -Identity <UserIdentifier> -DomainController <DC>
```

---

## 📞 Support & Feedback

For issues, feature requests, or feedback on v1.0.0-Beta1:

- Include reproduction steps
- Provide sanitized sync report CSV if applicable
- Note PowerShell version and OS version
- Include WhatIf output for non-destructive troubleshooting

---

## 🗺️ Roadmap (Future Versions)

- [ ] Multi-domain AD forest support
- [ ] Bulk user filtering by OU/group
- [ ] Scheduling/recurring sync capability
- [ ] Graphical user interface
- [ ] Performance optimization for large deployments (100K+ mailboxes)
- [ ] Enhanced error categorization and recovery suggestions
- [ ] PowerShell 7+ full compatibility testing

---

## 📄 License

[Add your license information here]

---

## 👥 Contributors

- Initial development and beta testing

---

**Version:** 1.0.0-Beta1  
**Release Date:** April 7, 2026  
**Status:** Beta (not recommended for production use without testing)
