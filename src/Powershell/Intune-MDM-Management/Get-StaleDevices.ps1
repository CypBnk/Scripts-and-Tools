<#
.SYNOPSIS
Find stale Entra devices and exclude Autopilot devices.

.DESCRIPTION
Retrieves Entra devices from Microsoft Graph and returns devices with
ApproximateLastSignInDateTime between -MinDays and -MaxDays (inclusive),
while excluding Autopilot devices by both:
1) ZTDID presence in PhysicalIds
2) A cross-check against Windows Autopilot registrations

By default, the script outputs PowerShell objects.
If -CsvPath is provided, results are also exported to CSV.

.PARAMETER MinDays
Minimum age in days since last sign-in (inclusive). Must be 60..3650.

.PARAMETER MaxDays
Maximum age in days since last sign-in (inclusive). Must be 60..3650.

.PARAMETER CsvPath
Optional path to export the filtered results as CSV.

.PARAMETER Scopes
Optional Microsoft Graph scopes. Defaults include required read scopes.

.EXAMPLE
.\Get-StaleDevices.ps1 -MinDays 60 -MaxDays 3650

.EXAMPLE
.\Get-StaleDevices.ps1 -MinDays 90 -MaxDays 365 -CsvPath .\stale-devices.csv
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateRange(60, 3650)]
    [int]$MinDays = 60,

    [Parameter(Mandatory = $false)]
    [ValidateRange(60, 3650)]
    [int]$MaxDays = 3650,

    [Parameter(Mandatory = $false)]
    [string]$CsvPath,

    [Parameter(Mandatory = $false)]
    [string[]]$Scopes = @(
        'Device.Read.All',
        'DeviceManagementServiceConfig.Read.All'
    )
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Connect-ToGraph {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$GraphScopes
    )

    if (-not (Get-Command -Name Connect-MgGraph -ErrorAction SilentlyContinue)) {
        throw 'Microsoft Graph PowerShell SDK is not installed. Install it with: Install-Module Microsoft.Graph -Scope CurrentUser'
    }

    $context = Get-MgContext
    if ($null -eq $context) {
        Write-Verbose 'Connecting to Microsoft Graph...'
        Connect-MgGraph -Scopes $GraphScopes -NoWelcome | Out-Null
        return
    }

    $missingScopes = @($GraphScopes | Where-Object { $_ -notin $context.Scopes })
    if ($missingScopes.Count -gt 0) {
        Write-Verbose ('Current Graph context missing scopes: {0}. Reconnecting...' -f ($missingScopes -join ', '))
        Disconnect-MgGraph -ErrorAction SilentlyContinue
        Connect-MgGraph -Scopes $GraphScopes -NoWelcome | Out-Null
    }
}

function Get-AllGraphPages {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3
    )

    $items = New-Object System.Collections.Generic.List[object]
    $nextLink = $Uri

    while ($nextLink) {
        $response = $null
        $attempt = 0

        while ($attempt -lt $MaxRetries) {
            try {
                $response = Invoke-MgGraphRequest -Method GET -Uri $nextLink
                break
            }
            catch {
                $attempt++
                $errorText = [string]$_.Exception.Message
                $isRetriable = $errorText -match 'HTTP/\d+(\.\d+)?\s+(429|5\d\d)' -or $errorText -match 'Too Many Requests|Internal Server Error|temporar'

                if (-not $isRetriable -or $attempt -ge $MaxRetries) {
                    throw
                }

                $delaySeconds = [Math]::Min(15, [int][Math]::Pow(2, $attempt))
                Write-Verbose ('Graph request failed (attempt {0}/{1}). Retrying in {2}s...' -f $attempt, $MaxRetries, $delaySeconds)
                Start-Sleep -Seconds $delaySeconds
            }
        }

        if ($response.PSObject.Properties.Name -contains 'value' -and $response.value) {
            foreach ($item in $response.value) {
                $items.Add($item)
            }
        }
        elseif ($null -ne $response) {
            # Some Graph calls can return a single object instead of a paged value array.
            $items.Add($response)
        }

        if ($response.PSObject.Properties.Name -contains '@odata.nextLink') {
            $nextLink = [string]$response.'@odata.nextLink'
        }
        else {
            $nextLink = $null
        }
    }

    return $items
}

function Test-HasZtdId {
    param(
        [Parameter(Mandatory = $false)]
        [object[]]$PhysicalIds
    )

    if ($null -eq $PhysicalIds) {
        return $false
    }

    foreach ($entry in $PhysicalIds) {
        if ([string]::IsNullOrWhiteSpace([string]$entry)) {
            continue
        }

        if ([string]$entry -match '^\[ZTDID\]:') {
            return $true
        }
    }

    return $false
}

function Get-ObjectPropertyValue {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Object,

        [Parameter(Mandatory = $true)]
        [string]$PropertyName
    )

    if ($null -eq $Object) {
        return $null
    }

    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($PropertyName)) {
            return $Object[$PropertyName]
        }
        return $null
    }

    $property = $Object.PSObject.Properties.Match($PropertyName) | Select-Object -First 1
    if ($null -ne $property) {
        return $property.Value
    }

    return $null
}

if ($MinDays -gt $MaxDays) {
    throw ('MinDays ({0}) must be less than or equal to MaxDays ({1}).' -f $MinDays, $MaxDays)
}

Connect-ToGraph -GraphScopes $Scopes

$nowUtc = [DateTime]::UtcNow

Write-Verbose 'Retrieving Entra devices from Microsoft Graph...'
$deviceUri = 'https://graph.microsoft.com/v1.0/devices?$select=id,deviceId,displayName,operatingSystem,approximateLastSignInDateTime,physicalIds,accountEnabled'
$devices = Get-AllGraphPages -Uri $deviceUri

Write-Verbose 'Retrieving Windows Autopilot identities from Microsoft Graph...'
$autopilotUri = 'https://graph.microsoft.com/v1.0/deviceManagement/windowsAutopilotDeviceIdentities'
$autopilotCrossCheckAvailable = $true
try {
    $autopilotDevices = Get-AllGraphPages -Uri $autopilotUri
}
catch {
    $autopilotCrossCheckAvailable = $false
    $autopilotDevices = @()
    Write-Warning 'Unable to retrieve Autopilot registrations from Graph. Continuing with ZTDID-only exclusion for this run.'
}

$autopilotLookup = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
foreach ($ap in $autopilotDevices) {
    $autopilotAadDeviceId = [string](Get-ObjectPropertyValue -Object $ap -PropertyName 'azureActiveDirectoryDeviceId')
    if (-not [string]::IsNullOrWhiteSpace($autopilotAadDeviceId)) {
        [void]$autopilotLookup.Add($autopilotAadDeviceId.Trim())
    }
}

$totalScanned = 0
$missingLastSignIn = 0
$staleCandidates = 0
$excludedByAutopilot = 0

$results = foreach ($device in $devices) {
    $totalScanned++

    $deviceObjectId = [string](Get-ObjectPropertyValue -Object $device -PropertyName 'id')
    $deviceId = [string](Get-ObjectPropertyValue -Object $device -PropertyName 'deviceId')
    $displayName = [string](Get-ObjectPropertyValue -Object $device -PropertyName 'displayName')
    $operatingSystem = [string](Get-ObjectPropertyValue -Object $device -PropertyName 'operatingSystem')
    $accountEnabled = Get-ObjectPropertyValue -Object $device -PropertyName 'accountEnabled'
    $physicalIds = Get-ObjectPropertyValue -Object $device -PropertyName 'physicalIds'
    $lastSignInRaw = [string](Get-ObjectPropertyValue -Object $device -PropertyName 'approximateLastSignInDateTime')

    if ([string]::IsNullOrWhiteSpace($lastSignInRaw)) {
        $missingLastSignIn++
        continue
    }

    try {
        $lastSignIn = [DateTimeOffset]::Parse($lastSignInRaw)
    }
    catch {
        Write-Verbose ('Skipping device with invalid approximateLastSignInDateTime. DeviceId={0}, ObjectId={1}' -f $deviceId, $deviceObjectId)
        continue
    }

    $daysSinceLastSignIn = [int][Math]::Floor(($nowUtc - $lastSignIn.UtcDateTime).TotalDays)
    if ($daysSinceLastSignIn -lt $MinDays -or $daysSinceLastSignIn -gt $MaxDays) {
        continue
    }

    $staleCandidates++

    $isAutopilotByZtdId = Test-HasZtdId -PhysicalIds $physicalIds
    $isAutopilotByRegistration = $false

    if ($autopilotCrossCheckAvailable -and -not [string]::IsNullOrWhiteSpace($deviceId)) {
        $isAutopilotByRegistration = $autopilotLookup.Contains($deviceId.Trim())
    }

    if ($autopilotCrossCheckAvailable -and -not $isAutopilotByRegistration -and -not [string]::IsNullOrWhiteSpace($deviceObjectId)) {
        $isAutopilotByRegistration = $autopilotLookup.Contains($deviceObjectId.Trim())
    }

    if ($isAutopilotByZtdId -or $isAutopilotByRegistration) {
        $excludedByAutopilot++
        continue
    }

    [PSCustomObject]@{
        DisplayName               = $displayName
        EntraObjectId             = $deviceObjectId
        EntraDeviceId             = $deviceId
        OperatingSystem           = $operatingSystem
        AccountEnabled            = [bool]$accountEnabled
        LastSignInDateTimeUtc     = $lastSignIn.UtcDateTime
        DaysSinceLastSignIn       = $daysSinceLastSignIn
        IsAutopilotByZtdId        = $isAutopilotByZtdId
        IsAutopilotByRegistration = $isAutopilotByRegistration
    }
}

Write-Verbose ('Total devices scanned: {0}' -f $totalScanned)
Write-Verbose ('Devices without last sign-in: {0}' -f $missingLastSignIn)
Write-Verbose ('Stale candidates in range ({0}-{1} days): {2}' -f $MinDays, $MaxDays, $staleCandidates)
Write-Verbose ('Excluded as Autopilot: {0}' -f $excludedByAutopilot)
Write-Verbose ('Autopilot registration cross-check available: {0}' -f $autopilotCrossCheckAvailable)
Write-Verbose ('Final stale non-Autopilot devices: {0}' -f (($results | Measure-Object).Count))

if (-not [string]::IsNullOrWhiteSpace($CsvPath)) {
    $results | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
    Write-Verbose ('CSV export completed: {0}' -f $CsvPath)
}

$results
