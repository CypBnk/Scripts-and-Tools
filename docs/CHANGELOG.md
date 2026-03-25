# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Releases]

### Added (Releases)
- Added standalone release elements `releases/SecurityGroupUsage.zip` and `releases/SecurityGroupUsage-RELEASE-v0.5.0-beta.1.md` for `SecurityGroupUsage` `v0.5.0-beta.1`.

## [Unreleased]

### Added (Unreleased)

- Added `src/Powershell/Intune-MDM-Management/Get-StaleDevices.ps1` to report stale Entra devices by configurable day range (`MinDays`/`MaxDays`, 60..3650).
- Added Autopilot exclusion logic in stale device reporting using both ZTDID detection and Windows Autopilot registration cross-check.
- Added `src/Powershell/Intune-MDM-Management/Invoke-EntraDeviceCleanup.ps1` as an interactive step-by-step cleanup workflow for Entra devices.
- Added a custom staleness threshold option in Step 2 of the cleanup workflow.
- Added a session step overview that shows read-only vs read+write flow before authentication.
- Added SecurityGroupUsage exports: `security-group-hygiene.csv`, `security-group-orphan-candidates.csv`, `security-group-duplicate-candidates.csv`, `security-group-nested-map.csv`, and `security-group-decision-matrix.csv`.
- Added Decision Matrix enrichment for security groups (`CleanupRecommendation`, `RecommendationReason`, `RequiredValidationStep`, `ValidationOwner`).
- Added SecurityGroupUsage collectors for Enterprise Applications app role assignments, Intune compliance/configuration profile assignments, and Exchange Online mail-enabled security groups.
- Added `Test-SguPrerequisites` for fail-fast SecurityGroupUsage startup validation (PowerShell version, Graph module/version, and required Graph commands).
- Added SecurityGroupUsage authentication mode selection (`WAM`, `DeviceCode`, `ClientCredentials`) with interactive prompt fallback.

### Changed

- Changed execution mode selection to happen before authentication in `src/Powershell/Invoke-EntraDeviceCleanup.ps1`.
- Changed `Invoke-Step0` to accept a permission level parameter instead of returning a mode choice.
- Changed SecurityGroupUsage evidence output so CSV and HTML evidence sections use one unified Evidence ViewModel.
- Changed SecurityGroupUsage HTML report layout to include section navigation, summary cards, and risk highlighting for decision matrix rows.
- Changed SecurityGroupUsage default Graph scope set to include `DeviceManagementConfiguration.Read.All`.
- Changed SecurityGroupUsage runtime UX to include step-based progress and workload progress indicators.
- Changed SecurityGroupUsage output folder structure to `<OutputPath>/<TenantName>/YYYY-MM-DD-HH_MM/<files>`.
- Changed SecurityGroupUsage enterprise app collection to show nested per-service-principal progress and verbose diagnostics (`Write-Progress` + `Write-Verbose`).
- Changed SecurityGroupUsage docs and examples to use `out/SecurityGroupUsage` as the output root and nested tenant/timestamp folders at runtime.
- Changed SecurityGroupUsage documentation in module README, API docs, and FAQ to include quick no-auth smoke testing and current output/coverage details.
- Changed `src/Powershell/SecurityGroupUsage/README.md` to a standalone zip-first quick start so the module can be run directly from the extracted release folder.

### Fixed

- Fixed Graph pagination/device retrieval handling for hashtable responses in `Get-AllGraphPages`.
- Fixed empty-device handling so sessions exit cleanly when no devices are returned.
- Fixed runtime syntax issues in property helper logic used by Graph response parsing.

### Removed

- Removed features

## [1.0.0] - 2026-01-16

### Added (1.0.0)

- Initial release of multi-script repository
- PowerShell script collection
- Python script collection
- Shell/Bash script collection
- JavaScript script collection
- Documentation and contribution guidelines
- GitHub Actions CI/CD workflows
- Test frameworks and examples

[Unreleased]: https://github.com/CypBnk/Scripts-and-Tools/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/CypBnk/Scripts-and-Tools/releases/tag/v1.0.0
