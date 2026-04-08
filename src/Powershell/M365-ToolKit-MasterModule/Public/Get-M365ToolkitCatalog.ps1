function Get-M365ToolkitCatalog {
    <#
    .SYNOPSIS
    Returns the M365 toolkit workload/action catalog.

    .DESCRIPTION
    Reads the toolkit catalog from Modules\ModuleCatalog.json and optionally filters by workload.

    .PARAMETER Workload
    Optional workload name to filter catalog items.

    .PARAMETER IncludePlaceholders
    Include placeholder records that are not yet runnable.

    .EXAMPLE
    Get-M365ToolkitCatalog

    .EXAMPLE
    Get-M365ToolkitCatalog -Workload Entra -IncludePlaceholders
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Workload,

        [Parameter(Mandatory = $false)]
        [switch]$IncludePlaceholders
    )

    $catalog = Get-ToolkitCatalog

    if ($PSBoundParameters.ContainsKey('Workload')) {
        $catalog = $catalog | Where-Object { $_.Workload -eq $Workload }
    }

    if (-not $IncludePlaceholders) {
        $catalog = $catalog | Where-Object { -not $_.IsPlaceholder }
    }

    $catalog
}