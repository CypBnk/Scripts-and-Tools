<#
.SYNOPSIS
    Establishes a connection to on-premises Exchange Server.

.DESCRIPTION
    Creates a remote PowerShell session to an on-premises Exchange server and imports the
    Exchange management shell commands. Uses RemoteExchange.ps1 initialization as a fallback
    for robust connection setup.

.PARAMETER ExchangeServer
    FQDN of the on-premises Exchange server to connect to.

.OUTPUTS
    [System.Management.Automation.Runspaces.PSSession] Remote session object

.EXAMPLE
    $Session = Connect-OnPremExchangeSession -ExchangeServer 'exchange.corp.com'

.NOTES
    Connection strategy:
    1. Attempts standard Microsoft.Exchange configuration PSSession
    2. If PSSession commands fail, falls back to RemoteExchange.ps1 initialization
    3. RemoteExchange.ps1 is the standard Exchange server profile script at:
       C:\Program Files\Microsoft\Exchange Server\V15\Bin\RemoteExchange.ps1
#>
function Connect-OnPremExchangeSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ExchangeServer
    )

    $Session = $null

    try {
        Write-Verbose -Message "Testing connectivity to on-premises Exchange server: $ExchangeServer"
        
        # Test if server is reachable
        $ConnectionTest = Test-NetConnection -ComputerName $ExchangeServer -Port 5985 -WarningAction SilentlyContinue -InformationAction SilentlyContinue
        if (-not $ConnectionTest.TcpTestSucceeded) {
            throw "Cannot reach Exchange server $ExchangeServer on port 5985 (WinRM)"
        }

        Write-Verbose -Message "Attempting standard Microsoft.Exchange PSSession connection..."

        try {
            $Session = New-PSSession -ComputerName $ExchangeServer `
                -ConfigurationName Microsoft.Exchange `
                -Authentication Kerberos `
                -ErrorAction Stop

            Write-Verbose -Message "Importing Exchange commands from remote session..."
            Import-PSSession $Session -CommandName @('Get-Mailbox', 'Set-Mailbox', 'Get-RemoteMailbox') `
                -AllowClobber -ErrorAction Stop | Out-Null

            Write-Verbose -Message "Successfully connected to on-premises Exchange via standard configuration"
            return $Session
        }
        catch {
            Write-Verbose -Message "Standard PSSession failed, attempting RemoteExchange.ps1 fallback: $_"

            if ($Session) {
                Remove-PSSession -Session $Session -ErrorAction SilentlyContinue | Out-Null
            }

            # Fallback: Use RemoteExchange.ps1 initialization
            $Session = New-PSSession -ComputerName $ExchangeServer `
                -Authentication Kerberos `
                -ErrorAction Stop

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
    }
    catch {
        if ($Session) {
            Remove-PSSession -Session $Session -ErrorAction SilentlyContinue | Out-Null
        }
        throw "Failed to connect to on-premises Exchange server $ExchangeServer : $_"
    }
}
