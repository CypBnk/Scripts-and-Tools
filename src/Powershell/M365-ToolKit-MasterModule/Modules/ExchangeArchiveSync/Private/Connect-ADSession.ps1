<#
.SYNOPSIS
    Verifies connectivity to on-premises Active Directory.

.DESCRIPTION
    Tests that the Active Directory module is available and can query the current domain.
    Optionally uses a specified domain controller for operations.
    Used to validate AD connectivity before performing write operations.

.PARAMETER DomainController
    Optional. Specific domain controller FQDN to use for AD operations.
    If not specified but ADDomain is provided, discovers DC in that domain.
    If neither specified, auto-discovers the PDC emulator of current domain.

.PARAMETER ADDomain
    Optional. Active Directory domain name to search for domain controller.
    Used as fallback if DomainController not specified.
    Example: 'contoso.com'

.OUTPUTS
    [bool] $true if AD is accessible, throws exception on failure.

.EXAMPLE
    Connect-ADSession
    # Returns $true if AD module is available and domain is accessible

.EXAMPLE
    Connect-ADSession -DomainController 'dc1.contoso.com'
    # Uses specified domain controller

.EXAMPLE
    Connect-ADSession -ADDomain 'contoso.com'
    # Discovers DC in specified domain
#>
function Connect-ADSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]
        $DomainController = $null,

        [Parameter(Mandatory = $false)]
        [string]
        $ADDomain = $null
    )

    try {
        Write-Verbose -Message "Checking for Active Directory module..."
        
        $ADModule = Get-Module -Name ActiveDirectory -ListAvailable -ErrorAction Stop
        if (-not $ADModule) {
            throw "ActiveDirectory module not found. Ensure RSAT-AD-PowerShell is installed on this machine."
        }

        Write-Verbose -Message "Importing Active Directory module..."
        Import-Module -Name ActiveDirectory -ErrorAction Stop | Out-Null

        Write-Verbose -Message "Testing AD connectivity..."
        
        # Resolve domain for DC discovery
        $TargetDomain = $null
        if (-not [string]::IsNullOrWhiteSpace($ADDomain)) {
            $TargetDomain = $ADDomain
            Write-Verbose -Message "Using specified fallback domain for discovery: $ADDomain"
        }
        else {
            $TargetDomain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().Name
            Write-Verbose -Message "Using current domain: $TargetDomain"
        }
        
        # Get domain object
        $Domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetDomain([System.DirectoryServices.ActiveDirectory.DirectoryContext]::new([System.DirectoryServices.ActiveDirectory.DirectoryContextType]::Domain, $TargetDomain))
        Write-Verbose -Message "Connected to domain: $($Domain.Name)"
        
        # Store DC reference for thread-through to AD cmdlets
        if ([string]::IsNullOrWhiteSpace($DomainController)) {
            $script:ADDomainController = $Domain.PdcRoleOwner.Name
            Write-Verbose -Message "Using PDC emulator for domain $($Domain.Name): $($script:ADDomainController)"
        }
        else {
            $script:ADDomainController = $DomainController
            Write-Verbose -Message "Using specified domain controller: $DomainController"
        }

        return $true
    }
    catch {
        $ErrorMessage = $_
        
        # Check if this is a non-domain-joined machine error
        if ($ErrorMessage -match "not associated with an Active Directory domain|Current security context is not associated") {
            Write-Warning -Message "This computer is not joined to an Active Directory domain or the current security context has no AD access."
            Write-Warning -Message "AD writes (msExchArchiveGUID attribute) will be skipped. Only on-premises Exchange will be updated."
            Write-Warning -Message "To use full functionality, run this script from a domain-joined computer with domain credentials."
            
            # Return $true anyway so sync can continue with Exchange-only writes
            return $true
        }
        
        throw "Failed to connect to Active Directory: $_"
    }
}
