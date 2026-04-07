<#
.SYNOPSIS
    Verifies connectivity to on-premises Active Directory.

.DESCRIPTION
    Tests that the Active Directory module is available and can query the current domain.
    Used to validate AD connectivity before performing write operations.

.OUTPUTS
    [bool] $true if AD is accessible, throws exception on failure.

.EXAMPLE
    Connect-ADSession
    # Returns $true if AD module is available and domain is accessible
#>
function Connect-ADSession {
    [CmdletBinding()]
    param()

    try {
        Write-Verbose -Message "Checking for Active Directory module..."
        
        $ADModule = Get-Module -Name ActiveDirectory -ListAvailable -ErrorAction Stop
        if (-not $ADModule) {
            throw "ActiveDirectory module not found. Ensure RSAT-AD-PowerShell is installed on this machine."
        }

        Write-Verbose -Message "Importing Active Directory module..."
        Import-Module -Name ActiveDirectory -ErrorAction Stop | Out-Null

        Write-Verbose -Message "Testing AD connectivity..."
        $Domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
        Write-Verbose -Message "Connected to domain: $($Domain.Name)"

        return $true
    }
    catch {
        throw "Failed to connect to Active Directory: $_"
    }
}
