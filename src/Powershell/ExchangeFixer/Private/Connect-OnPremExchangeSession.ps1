<#
.SYNOPSIS
    Establishes a connection to on-premises Exchange Server.

.DESCRIPTION
    Creates a remote PowerShell session to an on-premises Exchange server using Kerberos
    authentication and imports the Exchange management shell commands.

.PARAMETER ExchangeServer
    FQDN or NetBIOS name of the on-premises Exchange server to connect to.
    Example: 'exchange.corp.com' or 'exch01'

.PARAMETER Credential
    Optional. PSCredential object for authentication. If not provided, uses current user's identity.
    If current user lacks permissions, provide domain admin credentials:
    -Credential (Get-Credential -UserName 'DOMAIN\ExchangeAdmin')

.OUTPUTS
    [System.Management.Automation.Runspaces.PSSession] Remote session object

.EXAMPLE
    $Session = Connect-OnPremExchangeSession -ExchangeServer 'exchange.corp.com'
    # Uses current user credentials via Kerberos authentication

.EXAMPLE
    $Credential = Get-Credential
    $Session = Connect-OnPremExchangeSession -ExchangeServer 'exchange.corp.com' -Credential $Credential
    # Uses provided credentials via Kerberos authentication

.NOTES
    Connection method:
    - Uses explicit ConnectionUri: http://<ServerFQDN>/PowerShell/
    - Authentication: Kerberos
    
    Troubleshooting "Access is denied":
    - Verify user has Exchange Server Administrator or Organization Management role
    - Check WinRM is enabled: winrm quickconfig (run on Exchange server)
    - Verify firewall allows port 5985 (WinRM)
    - Provide explicit credentials if needed: -Credential (Get-Credential)
#>
function Connect-OnPremExchangeSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ExchangeServer,

        [Parameter(Mandatory = $false)]
        [PSCredential]
        $Credential
    )

    $Session = $null

    try {
        Write-Verbose -Message "Building connection URI for $ExchangeServer"
        
        $ConnectionUri = "http://$ExchangeServer/PowerShell/"
        
        Write-Verbose -Message "Attempting connection to $ConnectionUri with Kerberos authentication"

        $SessionParams = @{
            ConfigurationName = 'Microsoft.Exchange'
            ConnectionUri     = $ConnectionUri
            Authentication    = 'Kerberos'
            ErrorAction       = 'Stop'
        }

        if ($Credential) {
            $SessionParams['Credential'] = $Credential
        }

        $Session = New-PSSession @SessionParams
        
        Write-Verbose -Message "Remote session created, importing Exchange commands..."
        
        Import-PSSession $Session -ErrorAction Stop | Out-Null

        Write-Verbose -Message "Successfully connected and imported Exchange commands from $ExchangeServer"
        return $Session
    }
    catch {
        if ($Session) {
            Remove-PSSession -Session $Session -ErrorAction SilentlyContinue | Out-Null
        }
        
        $ErrorMessage = @(
            "Failed to connect to on-premises Exchange server $ExchangeServer",
            "Error: $($_.Exception.Message)",
            "",
            "Troubleshooting steps:",
            "1. Verify Exchange Administrator permissions"
            "   - User must be in 'Organization Management' or 'Exchange Server Administrators' role"
            "   - Run on Exchange server: Add-RoleGroupMember -Identity 'Organization Management' -Member 'domain\username'"
            "",
            "2. Verify WinRM configuration on target server"
            "   - Run on Exchange server: winrm quickconfig"
            "   - Check: Get-PSSessionConfiguration (look for Microsoft.Exchange)"
            "",
            "3. Verify network/firewall connectivity"
            "   - Test: Test-NetConnection $ExchangeServer -Port 5985"
            "   - Firewall must allow port 5985 (WinRM)"
            "",
            "4. Try with explicit credentials if not using Exchange admin account"
            "   - Example: Connect-OnPremExchangeSession -ExchangeServer $ExchangeServer -Credential (Get-Credential)"
        ) -join "`n"

        throw $ErrorMessage
    }
}
