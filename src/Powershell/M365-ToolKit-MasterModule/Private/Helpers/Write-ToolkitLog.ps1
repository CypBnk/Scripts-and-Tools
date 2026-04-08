function Write-ToolkitLog {
    <#
    .SYNOPSIS
    Appends a structured log entry to the toolkit log file.

    .PARAMETER Level
    Severity level: INFO, WARN, or ERROR.

    .PARAMETER Source
    The function or component name that produced the entry.

    .PARAMETER Message
    Human-readable description of what happened.

    .PARAMETER ErrorRecord
    Optional ErrorRecord from a catch block. When provided the exception message
    and script stack trace are appended automatically.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $logDir = Join-Path (Get-ToolkitRoot) 'Output'
    if (-not (Test-Path -Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }

    $logFile = Join-Path $logDir 'M365Toolkit.log'
    $timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'
    $entry = "[$timestamp] [$Level] [$Source] $Message"

    if ($null -ne $ErrorRecord) {
        $entry += "`n  Exception : $($ErrorRecord.Exception.Message)"
        if ($ErrorRecord.ScriptStackTrace) {
            $entry += "`n  StackTrace: $($ErrorRecord.ScriptStackTrace)"
        }
        if ($ErrorRecord.InvocationInfo -and $ErrorRecord.InvocationInfo.PositionMessage) {
            $entry += "`n  Position  : $($ErrorRecord.InvocationInfo.PositionMessage)"
        }
    }

    Add-Content -Path $logFile -Value $entry -Encoding UTF8
}
