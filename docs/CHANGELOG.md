# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Added `src/Powershell/Get-StaleDevices.ps1` to report stale Entra devices by configurable day range (`MinDays`/`MaxDays`, 60..3650).
- Added Autopilot exclusion logic in stale device reporting using both ZTDID detection and Windows Autopilot registration cross-check.
- Added `src/Powershell/Invoke-EntraDeviceCleanup.ps1` as an interactive step-by-step cleanup workflow for Entra devices.
- Added a custom staleness threshold option in Step 2 of the cleanup workflow.
- Added a session step overview that shows read-only vs read+write flow before authentication.

### Changed

- Changed execution mode selection to happen before authentication in `src/Powershell/Invoke-EntraDeviceCleanup.ps1`.
- Changed `Invoke-Step0` to accept a permission level parameter instead of returning a mode choice.

### Fixed

- Fixed Graph pagination/device retrieval handling for hashtable responses in `Get-AllGraphPages`.
- Fixed empty-device handling so sessions exit cleanly when no devices are returned.
- Fixed runtime syntax issues in property helper logic used by Graph response parsing.

### Removed

- Removed features

## [1.0.0] - 2026-01-16

### Added

- Initial release of multi-script repository
- PowerShell script collection
- Python script collection
- Shell/Bash script collection
- JavaScript script collection
- Documentation and contribution guidelines
- GitHub Actions CI/CD workflows
- Test frameworks and examples

[Unreleased]: https://github.com/username/PowerScripts/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/username/PowerScripts/releases/tag/v1.0.0
