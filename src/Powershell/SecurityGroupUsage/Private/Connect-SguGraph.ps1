function Connect-SguGraph {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Scopes
    )

    if (-not (Get-Command -Name Connect-MgGraph -ErrorAction SilentlyContinue)) {
        throw 'Microsoft Graph PowerShell SDK is not installed. Install-Module Microsoft.Graph -Scope CurrentUser'
    }

    $context = Get-MgContext
    if ($null -eq $context) {
        Write-Verbose 'Connecting to Microsoft Graph...'
        Connect-MgGraph -Scopes $Scopes -NoWelcome | Out-Null
        return
    }

    $missingScopes = @($Scopes | Where-Object { $_ -notin $context.Scopes })
    if ($missingScopes.Count -gt 0) {
        Write-Verbose ("Graph context missing scopes: {0}. Reconnecting..." -f ($missingScopes -join ', '))
        Disconnect-MgGraph -ErrorAction SilentlyContinue
        Connect-MgGraph -Scopes $Scopes -NoWelcome | Out-Null
    }
}
