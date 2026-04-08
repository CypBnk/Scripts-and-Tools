function Get-ToolkitCatalog {
    [CmdletBinding()]
    param()

    $catalogPath = Join-Path (Get-ToolkitRoot) 'Modules\ModuleCatalog.json'
    if (-not (Test-Path -Path $catalogPath -PathType Leaf)) {
        Write-ToolkitLog -Level ERROR -Source 'Get-ToolkitCatalog' -Message "Catalog file not found: $catalogPath"
        throw "Toolkit catalog not found: $catalogPath"
    }

    try {
        $json = Get-Content -Path $catalogPath -Raw -Encoding UTF8
        $data = $json | ConvertFrom-Json
    }
    catch {
        Write-ToolkitLog -Level ERROR -Source 'Get-ToolkitCatalog' -Message "Failed to parse catalog JSON: $catalogPath" -ErrorRecord $_
        throw
    }

    if ($null -eq $data -or $null -eq $data.Items) {
        Write-ToolkitLog -Level ERROR -Source 'Get-ToolkitCatalog' -Message "Catalog JSON is invalid (missing Items): $catalogPath"
        throw "Toolkit catalog is invalid: $catalogPath"
    }

    $data.Items
}