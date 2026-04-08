<#
.SYNOPSIS
    Initializes the Exchange environment using RemoteExchange.ps1 in a remote session.

.DESCRIPTION
    Dot-sources the Exchange Server RemoteExchange.ps1 initialization script in a remote session.
    This script sets up Exchange types, formats, cmdlets, and utilities.
    
    RemoteExchange.ps1 is located at:
    C:\Program Files\Microsoft\Exchange Server\V15\Bin\RemoteExchange.ps1

.PARAMETER Session
    Remote PSSession where RemoteExchange.ps1 should be initialized.

.PARAMETER RemoteExchangePath
    Optional. Full path to RemoteExchange.ps1 on the remote server.
    Default: C:\Program Files\Microsoft\Exchange Server\V15\Bin\RemoteExchange.ps1

.OUTPUTS
    [bool] $true on success, throws exception on failure

.EXAMPLE
    Initialize-RemoteExchange -Session $Session
    # Initializes Exchange environment in the remote session
#>
function Initialize-RemoteExchange {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.Runspaces.PSSession]
        $Session,

        [Parameter(Mandatory = $false)]
        [string]
        $RemoteExchangePath = 'C:\Program Files\Microsoft\Exchange Server\V15\Bin\RemoteExchange.ps1'
    )

    try {
        Write-Verbose -Message "Initializing RemoteExchange in session: $($Session.ComputerName)"

        Invoke-Command -Session $Session -ScriptBlock {
            param($ExchangeScript)

            Write-Verbose -Message "Checking for RemoteExchange.ps1 at: $ExchangeScript"

            if (-not (Test-Path -Path $ExchangeScript)) {
                throw "RemoteExchange.ps1 not found at $ExchangeScript on $env:COMPUTERNAME"
            }

            Write-Verbose -Message "Dot-sourcing RemoteExchange.ps1..."
            . $ExchangeScript
            Write-Verbose -Message "RemoteExchange.ps1 initialization completed successfully"
        } -ArgumentList $RemoteExchangePath -ErrorAction Stop

        Write-Verbose -Message "Remote Exchange environment initialized successfully"
        return $true
    }
    catch {
        throw "Failed to initialize RemoteExchange at $RemoteExchangePath : $_"
    }
}
