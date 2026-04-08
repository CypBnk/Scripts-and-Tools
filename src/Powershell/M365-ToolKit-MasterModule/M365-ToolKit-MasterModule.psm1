Set-StrictMode -Version Latest

$script:ToolkitRoot = $PSScriptRoot

$privateScripts = Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Recurse -Filter '*.ps1' -ErrorAction SilentlyContinue
foreach ($scriptFile in $privateScripts) {
    . $scriptFile.FullName
}

$publicScripts = Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Recurse -Filter '*.ps1' -ErrorAction SilentlyContinue
foreach ($scriptFile in $publicScripts) {
    . $scriptFile.FullName
}

$publicFunctionNames = $publicScripts.BaseName
Export-ModuleMember -Function $publicFunctionNames