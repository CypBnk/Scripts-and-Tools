<#
.SYNOPSIS
    Establishes a connection to on-premises Exchange Server.

.DESCRIPTION
    Creates a remote PowerShell session to an on-premises Exchange server and imports the
    Exchange management shell commands. Uses RemoteExchange.ps1 initialization as a fallback
    for robust connection setup.
    
    Connection attempts authentication methods in this order:
    1. Standard Microsoft.Exchange config (Basic Auth) with provided or current user credentials
    2. RemoteExchange.ps1 fallback (Basic Auth) with provided or current user credentials
    
    Basic Authentication supports both local and domain credentials and works reliably across
    different network configurations and domain boundaries.

.PARAMETER ExchangeServer
    FQDN or NetBIOS name of the on-premises Exchange server to connect to.
    Example: 'exchange.corp.com' or 'exch01'

.PARAMETER Credential
    Optional. PSCredential object for authentication. If not provided, uses current user's identity.
    Note: Basic Authentication requires explicit credentials for cross-domain scenarios.
    If current user lacks permissions, provide domain admin credentials:
    -Credential (Get-Credential -UserName 'DOMAIN\ExchangeAdmin')

.OUTPUTS
    [System.Management.Automation.Runspaces.PSSession] Remote session object

.EXAMPLE
    $Session = Connect-OnPremExchangeSession -ExchangeServer 'exchange.corp.com'
    # Uses current user credentials via Basic Authentication

.EXAMPLE
    $Credential = Get-Credential
    $Session = Connect-OnPremExchangeSession -ExchangeServer 'exchange.corp.com' -Credential $Credential
    # Uses provided credentials via Basic Authentication

.NOTES
    Connection strategy:
    1. Attempts Microsoft.Exchange configuration PSSession with Basic Authentication (preferred)
    2. Falls back to RemoteExchange.ps1 initialization if Microsoft.Exchange is unavailable
    3. RemoteExchange.ps1 path: C:\Program Files\Microsoft\Exchange Server\V15\Bin\RemoteExchange.ps1
    
    Authentication Notes:
    - Basic Authentication is the default for better cross-domain compatibility
    - Credentials are encrypted over WinRM port 5985
    - Works with both local Exchange admins and domain accounts
    
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
        Write-Verbose -Message "Testing connectivity to on-premises Exchange server: $ExchangeServer"
        
        # Test if server is reachable
        $ConnectionTest = Test-NetConnection -ComputerName $ExchangeServer -Port 5985 -WarningAction SilentlyContinue -InformationAction SilentlyContinue
        if (-not $ConnectionTest.TcpTestSucceeded) {
            throw "Cannot reach Exchange server $ExchangeServer on port 5985 (WinRM). Verify: 1) Server FQDN is correct, 2) WinRM is running on the server, 3) Firewall allows port 5985"
        }

        Write-Verbose -Message "Server connectivity verified: $ExchangeServer"

        # Prepare connection parameters
        $SessionParams = @{
            ComputerName   = $ExchangeServer
            ErrorAction    = 'Stop'
            Authentication = 'Basic'
        }

        if ($Credential) {
            $SessionParams['Credential'] = $Credential
            $AuthMethod = "alternate credentials"
        }
        else {
            $AuthMethod = "current user identity"
        }

        Write-Verbose -Message "Attempting standard Microsoft.Exchange PSSession connection with Basic Authentication using $AuthMethod..."

        try {
            $SessionParams['ConfigurationName'] = 'Microsoft.Exchange'
            
            $Session = New-PSSession @SessionParams

            Write-Verbose -Message "Importing Exchange commands from remote session..."
            Import-PSSession $Session -CommandName @('Get-Mailbox', 'Set-Mailbox', 'Get-RemoteMailbox') `
                -AllowClobber -ErrorAction Stop | Out-Null

            Write-Verbose -Message "Successfully connected to on-premises Exchange via standard configuration"
            return $Session
        }
        catch {
            $PrimaryError = $_
            Write-Verbose -Message "Standard PSSession failed: $($PrimaryError.Exception.Message)"

            if ($Session) {
                Remove-PSSession -Session $Session -ErrorAction SilentlyContinue | Out-Null
            }

            # Fallback: Use RemoteExchange.ps1 initialization
            Write-Verbose -Message "Attempting RemoteExchange.ps1 fallback with Basic Authentication using $AuthMethod..."

            try {
                $FallbackParams = @{
                    ComputerName   = $ExchangeServer
                    Authentication = 'Basic'
                    ErrorAction    = 'Stop'
                }

                if ($Credential) {
                    $FallbackParams['Credential'] = $Credential
                }

                $Session = New-PSSession @FallbackParams

                Write-Verbose -Message "Initializing Exchange environment via RemoteExchange.ps1..."

                $RemoteExchangePath = 'C:\Program Files\Microsoft\Exchange Server\V15\Bin\RemoteExchange.ps1'

                Invoke-Command -Session $Session -ScriptBlock {
                    param($RemoteExchangeScript)

                    if (Test-Path -Path $RemoteExchangeScript) {
                        Write-Verbose -Message "Loading RemoteExchange.ps1 for Exchange initialization..."
                        . $RemoteExchangeScript
                        Write-Verbose -Message "RemoteExchange.ps1 initialization completed"
                    }
                    else {
                        throw "RemoteExchange.ps1 not found at $RemoteExchangeScript on $env:COMPUTERNAME"
                    }
                } -ArgumentList $RemoteExchangePath -ErrorAction Stop

                Write-Verbose -Message "Importing Exchange commands from remote session..."
                Import-PSSession $Session -CommandName @('Get-Mailbox', 'Set-Mailbox', 'Get-RemoteMailbox') `
                    -AllowClobber -ErrorAction Stop | Out-Null

                Write-Verbose -Message "Successfully connected to on-premises Exchange via RemoteExchange.ps1 fallback"
                return $Session
            }
            catch {
                $FallbackError = $_
                Write-Verbose -Message "RemoteExchange.ps1 fallback also failed: $($FallbackError.Exception.Message)"

                # Provide helpful error message
                $ErrorMessage = @(
                    "Failed to connect to on-premises Exchange server $ExchangeServer",
                    "Error: $($PrimaryError.Exception.Message)",
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
                    "   - Firewall must allow port 5985 (WinRM/HTTP)"
                    "",
                    "4. Try with explicit credentials if not using Exchange admin account"
                    "   - Example: Connect-OnPremExchangeSession -ExchangeServer $ExchangeServer -Credential (Get-Credential)"
                    "",
                    "5. Verify Basic Authentication is enabled on Exchange server"
                    "   - Run on Exchange server: Set-WSManInstance -ResourceURI winrm/config/client -ValueSet @{AllowUnencrypted=`$false}"
                    "   - WinRM typically uses port 5985 (HTTP/Basic Auth)"
                ) -join "`n"

                throw $ErrorMessage
            }
        }
    }
    catch {
        if ($Session) {
            Remove-PSSession -Session $Session -ErrorAction SilentlyContinue | Out-Null
        }
        throw $_
    }
}
