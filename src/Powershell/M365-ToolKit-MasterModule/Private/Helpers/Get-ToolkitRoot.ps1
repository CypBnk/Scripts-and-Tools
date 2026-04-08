function Get-ToolkitRoot {
    [CmdletBinding()]
    param()

    if ($script:ToolkitRoot) {
        return $script:ToolkitRoot
    }

    $PSScriptRoot
}