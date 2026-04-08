function New-SguWorkloadMatrix {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Catalog
    )

    $matrix = foreach ($entry in $Catalog) {
        [pscustomobject]@{
            Id                 = $entry.Id
            Section            = $entry.Section
            UsageArea          = $entry.UsageArea
            Links              = $entry.Links
            Capability         = [string]$entry.Capability
            QueryStrategy      = [string]$entry.QueryStrategy
            RequiredScopes     = @($entry.RequiredScopes)
            EndpointCandidates = @($entry.EndpointCandidates)
        }
    }

    return , $matrix
}
