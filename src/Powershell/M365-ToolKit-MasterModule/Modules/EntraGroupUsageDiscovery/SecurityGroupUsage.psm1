Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$privatePath = Join-Path $PSScriptRoot 'Private'
$publicPath = Join-Path $PSScriptRoot 'Public'

if (Test-Path -Path $privatePath) {
    Get-ChildItem -Path $privatePath -Filter '*.ps1' | Sort-Object Name | ForEach-Object {
        . $_.FullName
    }
}

if (Test-Path -Path $publicPath) {
    Get-ChildItem -Path $publicPath -Filter '*.ps1' | Sort-Object Name | ForEach-Object {
        . $_.FullName
    }
}

Export-ModuleMember -Function @(
    'Invoke-SecurityGroupUsageDiscovery'
)
