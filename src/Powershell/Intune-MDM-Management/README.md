# Intune MDM Management Scripts

This folder contains PowerShell scripts for managing Microsoft Intune and Mobile Device Management (MDM) enrollment on Windows devices.

## Scripts

### Delete RegKeys.ps1

Removes stale Intune/MDM enrollment artifacts and reinitializes the enrollment process.

**Purpose:**

- Clean up failed or problematic Intune enrollments
- Remove orphaned scheduled tasks related to Enterprise Device Management
- Clear registry entries for Intune management
- Reset the MDM enrollment certificate
- Reinitiate the enrollment process to establish a fresh connection

**What This Script Does:**

1. **Removes Scheduled Tasks** - Deletes scheduled tasks in the EnterpriseMGMT folder that are associated with the current enrollment ID
2. **Cleans Registry** - Removes registry keys from multiple locations:
   - Enrollments
   - Enrollments Status
   - EnterpriseResourceManager Tracked
   - PolicyManager AdmxInstalled
   - PolicyManager Providers
   - Provisioning OMADM Accounts
   - Provisioning OMADM Logger
   - Provisioning OMADM Sessions
3. **Removes Task Cache** - Deletes the EnterpriseMgmt folder from the Task Scheduler cache
4. **Deletes Certificate** - Removes the Intune MDM Device CA certificate from the local machine store
5. **Reinitializes Enrollment** - Starts the deviceenroller.exe process to begin fresh MDM enrollment

**Prerequisites:**

- Windows 7 or higher
- PowerShell 5.0 or higher
- Administrator privileges (required - must run as Administrator)
- Device must be connected to the network
- Microsoft Intune/MDM service available
- Azure AD or Microsoft 365 account

**Usage:**

```powershell
# Run as Administrator
.\Delete\ RegKeys.ps1
```

**Caution:**

⚠️ **WARNING**: This script makes significant changes to system registry and scheduled tasks. Only use if you:

- Understand the implications of removing MDM enrollment
- Have encountered persistent Intune enrollment failures
- Have administrative approval
- Have backed up your system or can restore from recovery

**Expected Behavior:**

- Script runs without prompts (Confirm:$false)
- Device will lose MDM compliance temporarily
- Enrollment will restart automatically
- Enrollment process typically completes within 5-10 minutes
- Device must remain powered on and connected to network during process

**Troubleshooting:**

If the script fails:

1. Ensure you are running as Administrator
2. Verify network connectivity
3. Check that the enrollment ID is correctly identified
4. Review Windows Event Viewer for relevant errors
5. Restart the device and try again

**Credits & References:**

This script was inspired by and based on the methodology described in:

- [Manually re-enroll a co-managed or hybrid Azure AD join Windows 10 PC to Microsoft Intune without losing current configuration](https://www.maximerastello.com/manually-re-enroll-a-co-managed-or-hybrid-azure-ad-join-windows-10-pc-to-microsoft-intune-without-loosing-current-configuration/) by Maxime Rastello

**Related Documentation:**

- [Microsoft Intune Enrollment Troubleshooting](https://docs.microsoft.com/en-us/intune/enrollment/troubleshoot-windows-enrollment-errors)
- [Windows MDM Guide](https://docs.microsoft.com/en-us/windows/client-management/mdm/)
- [Intune Enrollment Overview](https://docs.microsoft.com/en-us/intune/enrollment/)

**Security Considerations:**

- This script modifies critical system registry locations
- Only run on devices you own or have explicit permission to manage
- Review the script contents before execution
- Keep audit logs of when this script is run
- Ensure proper change management procedures are followed

**Support:**

For issues or questions about Intune enrollment:

1. Check [Microsoft Intune Support](https://docs.microsoft.com/en-us/intune/)
2. Review device enrollment logs in Settings > Accounts > Access work or school
3. Contact your IT administrator or helpdesk
