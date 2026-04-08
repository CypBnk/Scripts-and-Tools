function Get-M365ToolkitLog {
    <#
    .SYNOPSIS
    Returns recent toolkit log entries for troubleshooting.

    .DESCRIPTION
    Reads the persistent log file (Output\M365Toolkit.log) and returns the most
    recent entries. Use -Tail to control how many lines are returned (default 50).
    Use -Raw to get the full untruncated file content.

    .PARAMETER Tail
    Number of most-recent lines to return. Default: 50.

    .PARAMETER Raw
    Return all log content without truncation.

    .EXAMPLE
    Get-M365ToolkitLog

    .EXAMPLE
    Get-M365ToolkitLog -Tail 100

    .EXAMPLE
    Get-M365ToolkitLog -Raw | Set-Clipboard
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 10000)]
        [int]$Tail = 50,

        [Parameter(Mandatory = $false)]
        [switch]$Raw
    )

    $logFile = Join-Path (Get-ToolkitRoot) 'Output\M365Toolkit.log'

    if (-not (Test-Path -Path $logFile -PathType Leaf)) {
        Write-Warning "No log file found at: $logFile"
        return
    }

    if ($Raw) {
        Get-Content -Path $logFile -Raw -Encoding UTF8
    }
    else {
        Get-Content -Path $logFile -Tail $Tail -Encoding UTF8
    }
}
