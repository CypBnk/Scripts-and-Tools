function ConvertTo-SplatHashtable {
    <#
    .SYNOPSIS
    Converts a flat argument array into a hashtable suitable for splatting.

    .DESCRIPTION
    Parses tokens like @('-OutputPath', '.\path', '-SkipGraph') into
    @{ OutputPath = '.\path'; SkipGraph = $true }.  This avoids positional
    binding issues that occur when array-splatting args deserialized from JSON.

    .PARAMETER ArgumentList
    Flat string array of arguments, e.g. from ModuleCatalog.json Args.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$ArgumentList
    )

    $result = [ordered]@{}
    $i = 0
    while ($i -lt $ArgumentList.Count) {
        $token = [string]$ArgumentList[$i]
        if ($token.StartsWith('-')) {
            # Handle '-ParamName Value' in a single token (e.g. user typed on one line)
            $stripped = $token.Substring(1)   # remove leading dash
            $spaceIdx = $stripped.IndexOf(' ')
            if ($spaceIdx -gt 0) {
                $paramName = $stripped.Substring(0, $spaceIdx)
                $paramValue = $stripped.Substring($spaceIdx + 1).Trim().Trim('"', "'")
                $result[$paramName] = $paramValue
                $i += 1
            }
            else {
                $paramName = $stripped
                $nextIndex = $i + 1
                if ($nextIndex -lt $ArgumentList.Count -and -not ([string]$ArgumentList[$nextIndex]).StartsWith('-')) {
                    $result[$paramName] = $ArgumentList[$nextIndex]
                    $i += 2
                }
                else {
                    # Switch parameter (no value follows, or next token is another parameter)
                    $result[$paramName] = $true
                    $i += 1
                }
            }
        }
        else {
            # Unexpected positional token — skip with warning
            Write-Warning "ConvertTo-SplatHashtable: Skipping unexpected positional token '$token'."
            $i += 1
        }
    }

    $result
}
