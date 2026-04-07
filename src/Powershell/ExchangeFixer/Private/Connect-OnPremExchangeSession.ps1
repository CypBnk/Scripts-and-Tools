<#
.SYNOPSIS
    Establishes a connection to on-premises Exchange Server.

.DESCRIPTION
    Creates a remote PowerShell session to an on-premises Exchange server and imports the
    Exchange management shell commands.

.PARAMETER ExchangeServer
    FQDN of the on-premises Exchange server to connect to.

.OUTPUTS
    [System.Management.Automation.Runspaces.PSSession] Remote session object

.EXAMPLE
    $Session = Connect-OnPremExchangeSession -ExchangeServer 'exchange.corp.com'
#>
function Connect-OnPremExchangeSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ExchangeServer
    )

    try {
        Write-Verbose -Message "Testing connectivity to on-premises Exchange server: $ExchangeServer"
        
        # Test if server is reachable
        $ConnectionTest = Test-NetConnection -ComputerName $ExchangeServer -Port 5985 -WarningAction SilentlyContinue -InformationAction SilentlyContinue
        if (-not $ConnectionTest.TcpTestSucceeded) {
            throw "Cannot reach Exchange server $ExchangeServer on port 5985 (WinRM)"
        }

        Write-Verbose -Message "Creating remote PSSession to $ExchangeServer..."
        
        $Session = New-PSSession -ComputerName $ExchangeServer `
            -ConfigurationName Microsoft.Exchange `
            -Authentication Kerberos `
            -ErrorAction Stop

        Write-Verbose -Message "Importing Exchange commands from remote session..."
        Import-PSSession $Session -CommandName @('Get-Mailbox', 'Set-Mailbox', 'Get-RemoteMailbox') -ErrorAction Stop | Out-Null

        Write-Verbose -Message "Successfully connected to on-premises Exchange"
        return $Session
    }
    catch {
        throw "Failed to connect to on-premises Exchange server $ExchangeServer : $_"
    }
}
