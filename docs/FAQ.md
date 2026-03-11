# Frequently Asked Questions (FAQ)

## General Questions

### What is this project?

[Brief description of the project and its purpose]

### Who maintains this project?

This project is maintained by [Your Name/Organization]. See [CONTRIBUTING.md](../CONTRIBUTING.md) for contributor information.

### Is this project still actively maintained?

Yes, we're actively developing and maintaining this project. Check the [CHANGELOG.md](CHANGELOG.md) for recent updates.

## Installation & Setup

### How do I install this project?

See the [Installation Guide](INSTALLATION.md) for detailed instructions.

### Do I need any special permissions?

Most features require only standard user permissions. Some advanced features may require administrator access.

### Can I use this on [specific OS/platform]?

This project supports Windows, macOS, and Linux. Platform-specific instructions are available in the [Installation Guide](INSTALLATION.md).

## Usage Questions

### Where can I find usage examples?

Check the [README.md](../README.md) and script-specific help output.

### How do I find stale Entra devices and exclude Autopilot devices?

Use `src/Powershell/Get-StaleDevices.ps1`.

Example:

```powershell
.\src\Powershell\Get-StaleDevices.ps1 -MinDays 60 -MaxDays 3650 -Verbose
```

Optional CSV export:

```powershell
.\src\Powershell\Get-StaleDevices.ps1 -MinDays 90 -MaxDays 365 -CsvPath .\stale-devices.csv
```

### How do I run the interactive Entra cleanup workflow?

Use `src/Powershell/Invoke-EntraDeviceCleanup.ps1`.

Example:

```powershell
.\src\Powershell\Invoke-EntraDeviceCleanup.ps1
```

The script guides you through authentication, listing, filtering (including a custom threshold), and optional deletion in read+write mode.

### How do I report a bug?

Please open an [issue](../../issues) with a clear description and steps to reproduce.

### Can I request a feature?

Absolutely! Please use [GitHub Discussions](../../discussions) or open a [feature request issue](../../issues).

## Troubleshooting

### Something isn't working. What should I do?

1. Check the [Installation Guide](INSTALLATION.md) troubleshooting section
2. Search existing [issues](../../issues)
3. Review the [API Documentation](API.md)
4. Open a new issue if you can't find a solution

### I found a security vulnerability. What should I do?

Please email security concerns to [your-email@example.com] instead of using the public issue tracker.

## Contributing

### How can I contribute?

See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines on code contributions, bug reports, and feature suggestions.

### What's the code style?

We follow [PEP 8](https://www.python.org/dev/peps/pep-0008/) for Python and [ESLint](https://eslint.org/) for JavaScript.

## License & Legal

### What license is this project under?

This project is licensed under the MIT License. See [LICENSE](../LICENSE) for details.

### Can I use this commercially?

Yes! The MIT License permits commercial use.

## Still Have Questions?

- Join our [Discussions](../../discussions)
- Check related documentation files
- Open an [issue](../../issues) if you think you've found a bug
