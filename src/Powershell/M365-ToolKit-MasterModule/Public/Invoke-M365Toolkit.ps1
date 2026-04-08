function Invoke-M365Toolkit {
    <#
    .SYNOPSIS
    Launches the M365 toolkit interface.

    .DESCRIPTION
    Starts the toolkit in XAML (WPF) mode or opens the HTML scaffold.

    .PARAMETER Interface
    Interface mode. Use Xaml for the native desktop GUI or Html for the scaffold.

    .EXAMPLE
    Invoke-M365Toolkit

    .EXAMPLE
    Invoke-M365Toolkit -Interface Html
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('Xaml', 'Html')]
        [string]$Interface = 'Xaml'
    )

    if ($Interface -eq 'Html') {
        $htmlPath = Join-Path (Get-ToolkitRoot) 'GUI\HTML\index.html'
        if (-not (Test-Path -Path $htmlPath -PathType Leaf)) {
            throw "HTML interface file not found: $htmlPath"
        }

        Start-Process -FilePath $htmlPath | Out-Null
        return
    }

    Start-ToolkitGui
}