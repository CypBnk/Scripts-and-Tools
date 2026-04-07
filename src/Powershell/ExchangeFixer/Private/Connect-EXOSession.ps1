<#
.SYNOPSIS
    Establishes a connection to Exchange Online using modern authentication.

.DESCRIPTION
    Connects to Exchange Online using the ExchangeOnlineManagement module with modern auth.
    Disconnects any existing session first to ensure a clean connection state.

.PARAMETER Verbose
    Display verbose information during connection process.

.OUTPUTS
    [bool] $true if connection successful, throws exception on failure.

.EXAMPLE
    Connect-EXOSession
    # Opens browser for Modern Auth sign-in to Exchange Online
#>
function Connect-EXOSession {
    [CmdletBinding()]
    param()

    try {
        Write-Verbose -Message "Checking for ExchangeOnlineManagement module..."
        
        try {
            $ExoModule = Get-Module -Name ExchangeOnlineManagement -ListAvailable -ErrorAction Stop | Select-Object -First 1
        }
        catch {
            throw "ExchangeOnlineManagement module not found. Please install: Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser"
        }

        if (-not $ExoModule) {
            throw "ExchangeOnlineManagement module not installed. Please run: Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser"
        }

        Write-Verbose -Message "ExchangeOnlineManagement module version: $($ExoModule.Version)"

        # Disconnect any existing session first
        Write-Verbose -Message "Disconnecting any existing Exchange Online sessions..."
        try {
            Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 500
        }
        catch {
            # Ignore errors from disconnect
        }

        # Connect with modern auth
        Write-Verbose -Message "Initiating connection to Exchange Online..."
        Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop

        Write-Verbose -Message "Successfully connected to Exchange Online"
        return $true
    }
    catch {
        throw "Failed to connect to Exchange Online: $_"
    }
}
