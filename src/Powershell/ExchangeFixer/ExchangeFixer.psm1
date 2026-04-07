#Requires -Version 5.1

# Set strict mode and error action at module level
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Get the module root directory
$ModuleRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent

# Dot-source private functions first
$PrivateFunctions = @(
    'Test-Prerequisites',
    'Connect-EXOSession',
    'Connect-OnPremExchangeSession',
    'Connect-ADSession',
    'Get-EXOMailboxesWithArchive',
    'Get-OnPremMailboxes',
    'Match-OnPremMailbox',
    'Sync-ArchiveGuidToOnPrem',
    'Invoke-ArchiveGuidSync',
    'Write-SyncReport'
)

foreach ($FunctionName in $PrivateFunctions) {
    $FunctionPath = Join-Path -Path $ModuleRoot -ChildPath "Private\$FunctionName.ps1"
    if (Test-Path -Path $FunctionPath) {
        . $FunctionPath
    }
    else {
        Write-Warning -Message "Private function $FunctionName not found at $FunctionPath"
    }
}

# Dot-source public functions
$PublicFunctions = @(
    'Sync-ArchiveGuidFromEXO'
)

foreach ($FunctionName in $PublicFunctions) {
    $FunctionPath = Join-Path -Path $ModuleRoot -ChildPath "Public\$FunctionName.ps1"
    if (Test-Path -Path $FunctionPath) {
        . $FunctionPath
    }
    else {
        Write-Warning -Message "Public function $FunctionName not found at $FunctionPath"
    }
}

# Run prerequisite check on module load
$PrereqCheckPassed = Test-Prerequisites

# Export only the public functions
Export-ModuleMember -Function $PublicFunctions
