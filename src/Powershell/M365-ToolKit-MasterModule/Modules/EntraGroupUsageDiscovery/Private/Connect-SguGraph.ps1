function Connect-SguGraph {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Scopes,

        [Parameter(Mandatory = $true)]
        [ValidateSet('WAM', 'DeviceCode', 'ClientCredentials')]
        [string]$AuthMethod,

        [Parameter(Mandatory = $false)]
        [string]$TenantId,

        [Parameter(Mandatory = $false)]
        [string]$ClientId,

        [Parameter(Mandatory = $false)]
        [SecureString]$ClientSecret
    )

    # Prerequisites already validated by Invoke-SecurityGroupUsageDiscovery; re-check ensures
    # the module is loaded when Connect-SguGraph is called outside the normal entry point.
    $prereqs = Test-SguPrerequisites -Silent

    # Always start from a clean process-scoped session so no cached token leaks between runs.
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null

    switch ($AuthMethod) {
        'WAM' {
            if (-not $prereqs.GraphAuth.SupportsWam) {
                throw ('WAM authentication requires Windows and Microsoft.Graph.Authentication >= {0}. Installed: {1}; Windows: {2}.' -f $prereqs.GraphAuth.MinimumVersion, $prereqs.GraphAuth.ModuleVersion, $prereqs.IsWindows)
            }

            Write-Verbose ('Authenticating via WAM (Microsoft.Graph.Authentication {0})...' -f $prereqs.GraphAuth.ModuleVersion)
            Connect-MgGraph -Scopes $Scopes -NoWelcome -ContextScope Process | Out-Null
        }
        'DeviceCode' {
            Write-Verbose 'Authenticating via Device Code Flow...'
            Connect-MgGraph -Scopes $Scopes -UseDeviceAuthentication -NoWelcome -ContextScope Process | Out-Null
        }
        'ClientCredentials' {
            if ([string]::IsNullOrWhiteSpace($TenantId)) { throw 'TenantId is required for ClientCredentials authentication.' }
            if ([string]::IsNullOrWhiteSpace($ClientId)) { throw 'ClientId is required for ClientCredentials authentication.' }
            if ($null -eq $ClientSecret) { throw 'ClientSecret is required for ClientCredentials authentication.' }

            $credential = [System.Management.Automation.PSCredential]::new($ClientId, $ClientSecret)
            Write-Verbose ('Authenticating via Client Credentials (ClientId: {0}, TenantId: {1})...' -f $ClientId, $TenantId)
            Connect-MgGraph -TenantId $TenantId -ClientSecretCredential $credential -NoWelcome -ContextScope Process | Out-Null
        }
    }
}
