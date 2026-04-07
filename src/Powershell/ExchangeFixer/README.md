# ExchangeFixer Module

PowerShell module for fixing Exchange Online and on-premises coexistence issues.

## Features

### Sync-ArchiveGuidFromEXO

Synchronizes ArchiveGUID values from Exchange Online to on-premises Active Directory and Exchange Server.

**What it does:**

- Retrieves all Exchange Online mailboxes with active archives
- Matches them to on-premises mailboxes by SAM/UPN
- Writes ArchiveGUID to both on-premises AD and Exchange
- Generates CSV report with detailed results
- Handles errors gracefully (continues on failure, reports all issues)

**Useful for:**

- Enabling on-premises servers to access Exchange Online archives
- Post-migration scenarios where archive metadata needs synchronization
- Bulk updates of ArchiveGUID across the organization

## Installation

### Step 1: Install Prerequisites

#### Exchange Online Management Module (v2.0.5 or later)

```powershell
Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser
```

#### Active Directory Module (RSAT)

Windows 10/11:

```powershell
Add-WindowsCapability -Online -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0"
```

Windows Server:

```powershell
Install-WindowsFeature RSAT-AD-PowerShell
```

### Step 2: Import the Module

```powershell
Import-Module -Path "C:\Develop\Scripts-and-Tools\src\Powershell\ExchangeFixer\ExchangeFixer.psm1" -Force
```

### Step 3: Verify Installation

```powershell
Get-Command -Module ExchangeFixer
# Should show: Sync-ArchiveGuidFromEXO
```

## Prerequisites & Permissions

### Required Roles

**Microsoft 365:**

- Global Administrator, or
- Exchange Online Administrator

**On-Premises:**

- Exchange Server Administrator
- Active Directory Domain Administrator (or equivalent OU delegation)

### Required on Running Machine

- Domain-joined machine
- Exchange Online Management Module (v2.0.5+)
- Active Directory module (RSAT)
- .NET Framework 4.7.2+
- PowerShell 5.1+

## Usage

### Basic Usage

Sync all ArchiveGUIDs from Exchange Online to on-premises:

```powershell
Sync-ArchiveGuidFromEXO -OnPremExchangeServer 'exchange.contoso.com'
```

When prompted, sign in with an account that has the required permissions.

Report is saved to: `.\ArchiveGuidSync_20260407_153022.csv`

### Dry-Run Mode (WhatIf)

Preview what would be synced without making any changes:

```powershell
Sync-ArchiveGuidFromEXO -OnPremExchangeServer 'exchange.contoso.com' -WhatIf -Verbose
```

This shows:

- Number of EXO mailboxes with archives
- Matching results
- ArchiveGUID values that would be synced

### Custom Report Location

Save the report to a specific path:

```powershell
Sync-ArchiveGuidFromEXO -OnPremExchangeServer 'exchange.contoso.com' `
    -OutputPath 'C:\Reports\Archive-Sync.csv'
```

### Verbose Output

Enable detailed logging to understand the sync process:

```powershell
$VerbosePreference = 'Continue'
Sync-ArchiveGuidFromEXO -OnPremExchangeServer 'exchange.contoso.com' -Verbose
```

Verbose output includes:

- Connection progress to each service
- Matching logic for each mailbox
- AD and Exchange write outcomes
- Detailed error messages

### With Confirmation Prompt

Require confirmation before syncing (default is auto-confirm):

```powershell
Sync-ArchiveGuidFromEXO -OnPremExchangeServer 'exchange.contoso.com' -Confirm
```

## How It Works

### Matching Strategy

On-premises mailboxes are matched to Exchange Online mailboxes in this order:

1. **By SAM Account Name** (primary)
   - Most reliable, assumes SAM is the same in both environments
2. **By UserPrincipalName** (secondary)
   - Falls back if SAM doesn't match
3. **By PrimarySmtpAddress** (fallback)
   - Last resort if UPN also doesn't match

### Data Flow

```
Exchange Online              On-Premises
━━━━━━━━━━━━━━━━┐           ┌━━━━━━━━━━━━━━━
     mailbox    │           │    mailbox
  + ArchiveGUID ├──Match───→├──────────────
                │  (SAM)    │   AD: update
                │           │   msExchArchiveGUID
                │           │
                │           │   Exchange:
                │           │   update ArchiveGUID
```

### Error Handling

The script uses a **continue-on-error** strategy:

- **Individual mailbox failures**: Logged and reported, but processing continues
- **Partial success**: If only AD or only Exchange write fails, status shows "Partial"
- **Matching failures**: Mailboxes without matches are skipped and logged
- **Archive not enabled**: EXO mailboxes without archives are skipped

This ensures maximum mailboxes are synced despite any issues.

## Report Format

The CSV report contains:

| Column        | Values                                      | Description                        |
| ------------- | ------------------------------------------- | ---------------------------------- |
| **Mailbox**   | email@domain.com                            | User's UPN or email address        |
| **Status**    | Success, Failed, Skipped, Success (Partial) | Sync outcome                       |
| **Message**   | Details...                                  | ArchiveGUID value or error details |
| **Timestamp** | 2026-04-07 15:30:22                         | When the sync was attempted        |

### Example Report

```csv
Mailbox,Status,Message,Timestamp
alice@contoso.com,Success,ArchiveGUID synced successfully: 7e8b3d1f-4a6c-4b2e-9f1a-2c3d4e5f6a7b (AD and Exchange updated),2026-04-07 15:30:22
bob@contoso.com,Success (Partial),ArchiveGUID synced partially: 5c2b1a9f-3d4e-4c1f-8a2b-0f1e2d3c4b5a (AD updated only),2026-04-07 15:30:23
charlie@contoso.com,Skipped,No matching on-premises mailbox found,2026-04-07 15:30:24
david@contoso.com,Failed,Exchange Update Failed: The RPC endpoint is offline,2026-04-07 15:30:25
```

## Troubleshooting

### "Cannot reach Exchange server...5985"

**Problem:** WinRM (port 5985) not reachable on on-premises Exchange server.

**Solutions:**

1. Verify server FQDN is correct
2. Check that WinRM is running: `winrm quickconfig` on server
3. Verify firewall allows port 5985 from your computer to the server
4. Ensure Remote Server Administration Tools (RSAT) are installed locally

### "ExchangeOnlineManagement module not found"

**Problem:** Exchange Online Management module not installed.

**Solution:**

```powershell
Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser
```

### "ActiveDirectory module not found"

**Problem:** RSAT not installed on your machine.

**Solution:**

- Windows 10/11: `Add-WindowsCapability -Online -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0"`
- Windows Server: `Install-WindowsFeature RSAT-AD-PowerShell`

### "Failed to update AD for user..."

**Problem:** Insufficient permissions to write to AD.

**Solutions:**

1. Verify you're Domain Administrator or have OU delegate permissions
2. Run PowerShell as Administrator
3. Run from a domain-joined computer

### "Set-Mailbox failed: The RPC endpoint is offline"

**Problem:** On-premises Exchange server is unavailable or overloaded.

**Solutions:**

1. Check Exchange server health: `Get-ServerHealth` (run on server)
2. Verify server has network connectivity
3. Check Exchange event logs for errors
4. Try running sync during off-hours when server load is lower
5. Consider syncing smaller batches of mailboxes

### Slow Performance

**Problem:** Sync is taking a long time.

**Reasons & Solutions:**

- **Large organization:** 10,000+ mailboxes → naturally slow; runs sequentially by design
- **Network latency:** High latency to Exchange server → verify network path
- **Server load:** On-premises Exchange under load → try during off-hours
- **AD replication:** Major AD replication delay → verify AD health

## Advanced Usage

### Scheduling Automated Syncs

Use Windows Task Scheduler to run periodic syncs:

```powershell
$ScriptBlock = {
    $DeploymentRoot = "C:\Develop\Scripts-and-Tools"
    Import-Module -Path "$DeploymentRoot\src\Powershell\ExchangeFixer\ExchangeFixer.psm1" -Force

    $ReportPath = "\\fileserver\ExchangeReports\ArchiveSync_$(Get-Date -Format 'yyyyMMdd').csv"
    Sync-ArchiveGuidFromEXO -OnPremExchangeServer 'exchange.contoso.com' `
        -OutputPath $ReportPath
}

# With service principal (if you have stored credentials)
# $Creds = Get-StoredCredential -Target 'SyncAccount'
# & $ScriptBlock
```

Then schedule via Task Scheduler:

```powershell
$Action = New-ScheduledTaskAction -ScriptBlock $ScriptBlock
$Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 2AM
Register-ScheduledTask -Action $Action -Trigger $Trigger -TaskName "ExchangeFixer-ArchiveSync" -RunLevel Highest
```

### Sync Specific Users

To sync only a subset of mailboxes, edit `Invoke-ArchiveGuidSync` to add filtering:

```powershell
# Before the sync loop, filter mailboxes:
$ExoMailboxes = Get-EXOMailboxesWithArchive | Where-Object { $_.Department -eq 'Sales' }
```

Or create a wrapper script that calls the main cmdlet and filters results.

## Support & Feedback

For issues or enhancements, please refer to the ExchangeFixer documentation repository.

## Version History

### v1.0 (2026-04-07)

- Initial release
- Support for syncing ArchiveGUID from EXO to on-premises
- CSV reporting
- Continue-on-error strategy
