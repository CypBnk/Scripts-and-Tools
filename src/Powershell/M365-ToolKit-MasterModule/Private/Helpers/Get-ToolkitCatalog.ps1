function Get-ToolkitCatalog {
    [CmdletBinding()]
    param()

    $catalogPath = Join-Path (Get-ToolkitRoot) 'Modules\ModuleCatalog.json'
    if (-not (Test-Path -Path $catalogPath -PathType Leaf)) {
        throw "Toolkit catalog not found: $catalogPath"
    }

    $json = Get-Content -Path $catalogPath -Raw -Encoding UTF8
    $data = $json | ConvertFrom-Json

    if ($null -eq $data -or $null -eq $data.Items) {
        throw "Toolkit catalog is invalid: $catalogPath"
    }

    $data.Items
}