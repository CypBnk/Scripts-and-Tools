function Write-SguOutputs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [Parameter(Mandatory = $true)]
        [object[]]$Catalog,

        [Parameter(Mandatory = $true)]
        [object[]]$Matrix,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Evidence,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Coverage,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Telemetry,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$SecurityGroups,

        [Parameter(Mandatory = $true)]
        [bool]$GraphEnabled,

        [Parameter(Mandatory = $false)]
        [string]$CatalogSource = 'InternalEndpointCatalog'
    )

    $null = New-Item -Path $OutputPath -ItemType Directory -Force

    $jsonPath = Join-Path $OutputPath 'security-group-usage.json'
    $csvPath = Join-Path $OutputPath 'security-group-usage-mapping.csv'
    $mdPath = Join-Path $OutputPath 'security-group-usage-report.md'
    $htmlPath = Join-Path $OutputPath 'security-group-usage-report.html'

    $payload = [ordered]@{
        metadata       = [ordered]@{
            generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
            graphEnabled   = $GraphEnabled
            catalogSource  = $CatalogSource
        }
        catalog        = $Catalog
        workloadMatrix = $Matrix
        coverage       = $Coverage
        evidence       = $Evidence
        securityGroups = $SecurityGroups
        telemetry      = $Telemetry
    }

    $payload | ConvertTo-Json -Depth 12 | Set-Content -Path $jsonPath -Encoding UTF8

    $Evidence |
    Select-Object WorkloadId, Workload, Section, GroupId, GroupDisplayName, ObjectType, ObjectId, ObjectName, AssignmentMode, SourceType, SourceLink |
    Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

    $summaryLines = @()
    $summaryLines += '# Security Group Usage Discovery Report'
    $summaryLines += ''
    $summaryLines += ('Generated (UTC): {0}' -f (Get-Date).ToUniversalTime().ToString('u'))
    $summaryLines += ('Catalog source: {0}' -f $CatalogSource)
    $summaryLines += ('Graph enrichment enabled: {0}' -f $GraphEnabled)
    $summaryLines += ''
    $summaryLines += '## Coverage Summary'
    $summaryLines += ''
    $summaryLines += '| Workload | Capability | Status | Findings |'
    $summaryLines += '|---|---|---|---:|'
    foreach ($row in $Coverage) {
        $summaryLines += ('| {0} | {1} | {2} | {3} |' -f $row.Workload, $row.Capability, $row.Status, $row.Findings)
    }

    $summaryLines += ''
    $summaryLines += '## Security Groups and Usage'
    $summaryLines += ''
    $summaryLines += '| GroupId | GroupDisplayName | UsageCount | Workloads | Sample Objects |'
    $summaryLines += '|---|---|---:|---|---|'

    $effectiveSecurityGroups = @($SecurityGroups)
    if ($effectiveSecurityGroups.Count -eq 0 -and $Evidence.Count -gt 0) {
        $effectiveSecurityGroups = @(
            $Evidence |
            Group-Object -Property GroupId |
            ForEach-Object {
                $first = $_.Group | Select-Object -First 1
                [pscustomobject]@{
                    GroupId          = [string]$_.Name
                    GroupDisplayName = [string]$first.GroupDisplayName
                    MailEnabled      = $null
                    GroupTypes       = ''
                }
            }
        )
    }

    foreach ($group in ($effectiveSecurityGroups | Sort-Object GroupDisplayName, GroupId)) {
        $groupId = [string]$group.GroupId
        if ([string]::IsNullOrWhiteSpace($groupId)) { continue }

        $groupEvidence = @($Evidence | Where-Object { [string]$_.GroupId -eq $groupId })
        $usageCount = $groupEvidence.Count
        $workloads = if ($usageCount -gt 0) {
            ((@($groupEvidence.Workload) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Sort-Object -Unique) -join '; ')
        }
        else {
            'Not referenced in collected workloads'
        }

        $sampleObjects = if ($usageCount -gt 0) {
            ((@($groupEvidence.ObjectName) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Sort-Object -Unique | Select-Object -First 5) -join '; ')
        }
        else {
            ''
        }

        $groupDisplayName = [string]$group.GroupDisplayName
        $safeGroupDisplayName = $groupDisplayName -replace '\|', '\\|'
        $safeWorkloads = [string]$workloads -replace '\|', '\\|'
        $safeSampleObjects = [string]$sampleObjects -replace '\|', '\\|'

        $summaryLines += ('| {0} | {1} | {2} | {3} | {4} |' -f $groupId, $safeGroupDisplayName, $usageCount, $safeWorkloads, $safeSampleObjects)
    }

    $summaryLines += ''
    $summaryLines += '## Endpoint Catalog'
    $summaryLines += ''
    $summaryLines += '| Workload | Capability | Candidate Endpoints |'
    $summaryLines += '|---|---|---|'
    foreach ($row in $Matrix) {
        $joinedEndpoints = ((@($row.EndpointCandidates) | ForEach-Object { [string]$_ }) -join '<br/>')
        $summaryLines += ('| {0} | {1} | {2} |' -f $row.UsageArea, $row.Capability, $joinedEndpoints)
    }

    $summaryLines += ''
    $summaryLines += '## Findings by Workload'
    $summaryLines += ''

    $grouped = $Evidence | Group-Object -Property Workload
    foreach ($group in $grouped) {
        $summaryLines += ('### {0}' -f $group.Name)
        $summaryLines += ''
        $summaryLines += '| GroupId | GroupDisplayName | ObjectType | ObjectName | AssignmentMode |'
        $summaryLines += '|---|---|---|---|---|'
        foreach ($item in $group.Group) {
            $summaryLines += ('| {0} | {1} | {2} | {3} | {4} |' -f $item.GroupId, $item.GroupDisplayName, $item.ObjectType, $item.ObjectName, $item.AssignmentMode)
        }
        $summaryLines += ''
    }

    Set-Content -Path $mdPath -Value $summaryLines -Encoding UTF8

    $htmlTitle = "<h1>Security Group Usage Discovery Report</h1><p>Generated (UTC): $((Get-Date).ToUniversalTime().ToString('u'))</p>"
    $coverageHtml = $Coverage | Select-Object Workload, Capability, Status, Findings | ConvertTo-Html -Fragment -PreContent '<h2>Coverage Summary</h2>'
    $securityGroupUsageRows = @()
    foreach ($group in ($effectiveSecurityGroups | Sort-Object GroupDisplayName, GroupId)) {
        $groupId = [string]$group.GroupId
        if ([string]::IsNullOrWhiteSpace($groupId)) { continue }

        $groupEvidence = @($Evidence | Where-Object { [string]$_.GroupId -eq $groupId })
        $usageCount = $groupEvidence.Count
        $workloads = if ($usageCount -gt 0) {
            ((@($groupEvidence.Workload) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Sort-Object -Unique) -join '; ')
        }
        else {
            'Not referenced in collected workloads'
        }

        $sampleObjects = if ($usageCount -gt 0) {
            ((@($groupEvidence.ObjectName) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Sort-Object -Unique | Select-Object -First 5) -join '; ')
        }
        else {
            ''
        }

        $securityGroupUsageRows += [pscustomobject]@{
            GroupId          = $groupId
            GroupDisplayName = [string]$group.GroupDisplayName
            UsageCount       = $usageCount
            Workloads        = $workloads
            SampleObjects    = $sampleObjects
        }
    }

    $groupUsageHtml = $securityGroupUsageRows | ConvertTo-Html -Fragment -PreContent '<h2>Security Groups and Usage</h2>'
    $evidenceHtml = $Evidence | Select-Object Workload, Section, GroupId, GroupDisplayName, ObjectType, ObjectName, AssignmentMode, SourceType | ConvertTo-Html -Fragment -PreContent '<h2>Evidence</h2>'

    @(
        '<html><head><meta charset="utf-8" /><title>Security Group Usage Report</title><style>body{font-family:Segoe UI,Arial,sans-serif;margin:20px;} table{border-collapse:collapse;width:100%;margin-bottom:20px;} th,td{border:1px solid #ddd;padding:8px;text-align:left;} th{background:#f2f2f2;}</style></head><body>'
        $htmlTitle
        $coverageHtml
        $groupUsageHtml
        $evidenceHtml
        '</body></html>'
    ) | Set-Content -Path $htmlPath -Encoding UTF8

    return [pscustomobject]@{
        JsonPath     = $jsonPath
        CsvPath      = $csvPath
        MarkdownPath = $mdPath
        HtmlPath     = $htmlPath
    }
}
