function Invoke-SguGraphPagedRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3
    )

    $items = New-Object System.Collections.Generic.List[object]
    $nextLink = $Uri

    while ($nextLink) {
        $response = $null
        $attempt = 0

        while ($attempt -lt $MaxRetries) {
            try {
                $response = Invoke-MgGraphRequest -Method GET -Uri $nextLink
                break
            }
            catch {
                $attempt++
                $errorText = [string]$_.Exception.Message
                $isRetriable = $errorText -match 'HTTP/\d+(\.\d+)?\s+(429|5\d\d)' -or $errorText -match 'Too Many Requests|Internal Server Error|temporar'
                if (-not $isRetriable -or $attempt -ge $MaxRetries) {
                    throw
                }

                $delaySeconds = [Math]::Min(15, [int][Math]::Pow(2, $attempt))
                Write-Verbose ("Graph request failed ({0}/{1}). Retrying in {2}s" -f $attempt, $MaxRetries, $delaySeconds)
                Start-Sleep -Seconds $delaySeconds
            }
        }

        $responseItems = $null
        if ($null -ne $response) {
            if ($response -is [System.Collections.IDictionary]) {
                if ($response.Contains('value')) {
                    $responseItems = $response['value']
                }
            }
            elseif ($response.PSObject.Properties.Name -contains 'value') {
                $responseItems = $response.value
            }
        }

        if ($null -ne $responseItems) {
            foreach ($item in @($responseItems)) {
                $items.Add($item)
            }
        }
        elseif ($null -ne $response) {
            $items.Add($response)
        }

        if ($null -ne $response) {
            if ($response -is [System.Collections.IDictionary] -and $response.Contains('@odata.nextLink')) {
                $nextLink = [string]$response['@odata.nextLink']
            }
            elseif ($response.PSObject.Properties.Name -contains '@odata.nextLink') {
                $nextLink = [string]$response.'@odata.nextLink'
            }
            else {
                $nextLink = $null
            }
        }
        else {
            $nextLink = $null
        }
    }

    return $items.ToArray()
}
