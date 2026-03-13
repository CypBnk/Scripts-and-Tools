# Intune MDM Management Scripts

PowerShell scripts in this folder help with Intune and Entra device lifecycle operations:

- Repairing broken Windows MDM enrollment state
- Finding stale Entra devices while excluding Autopilot devices
- Guided cleanup (optional deletion) of stale non-Autopilot Entra devices

## Scripts

### Delete RegKeys.ps1

Removes stale Intune/MDM enrollment artifacts from a Windows device and triggers re-enrollment.

What it does:

1. Resolves the current EnterpriseMGMT enrollment ID from scheduled tasks.
2. Removes EnterpriseMGMT scheduled tasks for that enrollment.
3. Deletes enrollment-related registry keys under:
   - `HKLM:\SOFTWARE\Microsoft\Enrollments`
   - `HKLM:\SOFTWARE\Microsoft\Enrollments\Status`
   - `HKLM:\SOFTWARE\Microsoft\EnterpriseResourceManager\Tracked`
   - `HKLM:\SOFTWARE\Microsoft\PolicyManager\AdmxInstalled`
   - `HKLM:\SOFTWARE\Microsoft\PolicyManager\Providers`
   - `HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts`
   - `HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Logger`
   - `HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Sessions`
4. Removes related Task Scheduler cache path under `TaskCache\Tree\Microsoft\Windows\EnterpriseMgmt`.
5. Removes `Microsoft Intune MDM Device CA` certificate from `cert:\LocalMachine\My`.
6. Starts `deviceenroller.exe /c /AutoEnrollMDM`.

Usage (run as Administrator):

```powershell
.\Delete RegKeys.ps1
```

Notes:

- This is a high-impact local remediation script.
- The device can become temporarily non-compliant until enrollment is re-established.
- Keep the device online during re-enrollment.

### Get-StaleDevices.ps1 - WIP

Queries Microsoft Graph for stale Entra devices and excludes Autopilot devices.

Filtering behavior:

- Uses `approximateLastSignInDateTime` range (`-MinDays` to `-MaxDays`, inclusive)
- Excludes Autopilot devices by:
  - `[ZTDID]` marker in `physicalIds`
  - Cross-check against `windowsAutopilotDeviceIdentities` registrations (when available)

Key parameters:

- `MinDays` (default `60`, range `60..3650`)
- `MaxDays` (default `3650`, range `60..3650`)
- `CsvPath` (optional export path)
- `Scopes` (optional Graph scopes)

Examples:

```powershell
.\Get-StaleDevices.ps1 -MinDays 60 -MaxDays 3650
```

```powershell
.\Get-StaleDevices.ps1 -MinDays 90 -MaxDays 365 -CsvPath .\stale-devices.csv
```

### Invoke-EntraDeviceCleanup.ps1 - WIP

Interactive workflow for reviewing and optionally deleting stale non-Autopilot Entra devices.

Session flow:

1. Authentication (read-only or read+write mode)
2. Device inventory listing (with owner, OS, trust type, compliance, last sign-in)
3. Staleness filter (30 / 90 / 365 days or custom)
4. Optional delete step for eligible non-Autopilot devices

Safety and logging:

- Autopilot devices are excluded from deletion candidates.
- Deletion requires explicit typed confirmation (`yes`).
- Step logs are written to `%TEMP%\Magentascripts\<timestamp>_Step<N>.log`.

Usage:

```powershell
.\Invoke-EntraDeviceCleanup.ps1
```

## Prerequisites

- Windows PowerShell 5.1 or PowerShell 7+
- Microsoft Graph PowerShell SDK installed (`Install-Module Microsoft.Graph -Scope CurrentUser`)
- Network connectivity to Microsoft Graph
- Appropriate Entra/Intune permissions and admin consent where required

Suggested delegated Graph scopes used by scripts in this folder:

- `Device.Read.All`
- `DeviceManagementServiceConfig.Read.All`
- `Device.ReadWrite.All` (required only for deletion in read+write mode)

## Operational Guidance

- Test in a pilot or lab tenant/device group first.
- Use read-only discovery before enabling deletion workflows.
- Export and review stale device lists before cleanup decisions.
- Follow your organization's change-control process.

## References

- [Manually re-enroll a co-managed or hybrid Azure AD join Windows 10 PC to Microsoft Intune without losing current configuration](https://www.maximerastello.com/manually-re-enroll-a-co-managed-or-hybrid-azure-ad-join-windows-10-pc-to-microsoft-intune-without-loosing-current-configuration/)
- [Troubleshoot Windows enrollment errors in Intune](https://learn.microsoft.com/intune/intune-service/enrollment/troubleshoot-windows-enrollment-errors)
- [What is device management? (Windows client MDM)](https://learn.microsoft.com/windows/client-management/mdm/)
- [Intune enrollment guide](https://learn.microsoft.com/intune/intune-service/enrollment/)
