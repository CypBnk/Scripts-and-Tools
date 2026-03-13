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
    $hygieneCsvPath = Join-Path $OutputPath 'security-group-hygiene.csv'
    $orphanCsvPath = Join-Path $OutputPath 'security-group-orphan-candidates.csv'
    $duplicateCsvPath = Join-Path $OutputPath 'security-group-duplicate-candidates.csv'
    $nestedCsvPath = Join-Path $OutputPath 'security-group-nested-map.csv'
    $decisionCsvPath = Join-Path $OutputPath 'security-group-decision-matrix.csv'
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

    $evidenceViewModel = @(
        $Evidence | Select-Object WorkloadId, Workload, Section, GroupId, GroupDisplayName, ObjectType, ObjectId, ObjectName, AssignmentMode, SourceType, SourceLink
    )

    $evidenceViewModel | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

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

        $ownerCount = [int]$group.OwnerCount
        $memberCount = [int]$group.MemberCount
        $parentGroupCount = [int]$group.ParentGroupCount
        $childGroupCount = [int]$group.ChildGroupCount
        $duplicateByName = [bool]$group.DuplicateByName
        $duplicateByMail = [bool]$group.DuplicateByMail

        $noOwners = if ($null -ne $group.NoOwners) { [bool]$group.NoOwners } else { $ownerCount -eq 0 }
        $noMembers = if ($null -ne $group.NoMembers) { [bool]$group.NoMembers } else { $memberCount -eq 0 }
        $noUsageEvidence = ($usageCount -eq 0)
        $potentiallyOrphaned = $noOwners -and $noMembers -and $noUsageEvidence -and ($parentGroupCount -eq 0) -and ($childGroupCount -eq 0)

        # Decision Matrix
        $cleanupRecommendation = ''
        $recommendationReason = ''
        $requiredValidationStep = ''
        $validationOwner = ''

        if ($noOwners -and $noMembers -and $noUsageEvidence -and ($parentGroupCount -eq 0) -and ($childGroupCount -eq 0)) {
            $cleanupRecommendation = 'RemoveCandidate'
            $recommendationReason = 'No owners, no members, no usage evidence and not nested'
            $requiredValidationStep = 'Verify no workload dependency outside collected scopes; confirm with IAM team before deletion'
            $validationOwner = 'IAM Team'
        }
        elseif ($noUsageEvidence -or $noOwners -or $noMembers -or $duplicateByName -or $duplicateByMail) {
            $cleanupRecommendation = 'Review'
            $reasons = @()
            if ($noUsageEvidence) { $reasons += 'no usage evidence' }
            if ($noOwners) { $reasons += 'no owners' }
            if ($noMembers) { $reasons += 'no members' }
            if ($duplicateByName) { $reasons += 'name duplicate' }
            if ($duplicateByMail) { $reasons += 'mail duplicate' }
            $recommendationReason = 'Partial hygiene concerns: ' + ($reasons -join ', ')
            $requiredValidationStep = 'Assign an owner, validate current purpose, resolve duplicates or plan for decommission'
            $validationOwner = 'Application Owner / IT Security'
        }
        else {
            $cleanupRecommendation = 'Keep'
            $recommendationReason = 'Active usage evidence with healthy governance indicators'
            $requiredValidationStep = 'Periodic review recommended'
            $validationOwner = 'IAM Team'
        }

        $group | Add-Member -NotePropertyName 'CleanupRecommendation'    -NotePropertyValue $cleanupRecommendation    -Force
        $group | Add-Member -NotePropertyName 'RecommendationReason'     -NotePropertyValue $recommendationReason     -Force
        $group | Add-Member -NotePropertyName 'RequiredValidationStep'   -NotePropertyValue $requiredValidationStep   -Force
        $group | Add-Member -NotePropertyName 'ValidationOwner'          -NotePropertyValue $validationOwner          -Force

        $group.NoUsageEvidence = $noUsageEvidence
        $group.PotentiallyOrphaned = $potentiallyOrphaned

        $groupDisplayName = [string]$group.GroupDisplayName
        $safeGroupDisplayName = $groupDisplayName -replace '\|', '\\|'
        $safeWorkloads = [string]$workloads -replace '\|', '\\|'
        $safeSampleObjects = [string]$sampleObjects -replace '\|', '\\|'

        $summaryLines += ('| {0} | {1} | {2} | {3} | {4} |' -f $groupId, $safeGroupDisplayName, $usageCount, $safeWorkloads, $safeSampleObjects)
    }

    $summaryLines += ''
    $summaryLines += '## Governance and Cleanup Indicators'
    $summaryLines += ''
    $summaryLines += '| GroupId | GroupDisplayName | OwnerCount | MemberCount | ParentGroups | ChildGroups | NoUsageEvidence | PotentiallyOrphaned | DuplicateByName | DuplicateByMail |'
    $summaryLines += '|---|---|---:|---:|---:|---:|---|---|---|---|'
    foreach ($group in ($effectiveSecurityGroups | Sort-Object GroupDisplayName, GroupId)) {
        $groupId = [string]$group.GroupId
        if ([string]::IsNullOrWhiteSpace($groupId)) { continue }

        $groupDisplayName = ([string]$group.GroupDisplayName) -replace '\|', '\\|'
        $ownerCount = [int]$group.OwnerCount
        $memberCount = [int]$group.MemberCount
        $parentGroupCount = [int]$group.ParentGroupCount
        $childGroupCount = [int]$group.ChildGroupCount
        $noUsageEvidence = [bool]$group.NoUsageEvidence
        $potentiallyOrphaned = [bool]$group.PotentiallyOrphaned
        $duplicateByName = [bool]$group.DuplicateByName
        $duplicateByMail = [bool]$group.DuplicateByMail

        $summaryLines += ('| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} | {9} |' -f $groupId, $groupDisplayName, $ownerCount, $memberCount, $parentGroupCount, $childGroupCount, $noUsageEvidence, $potentiallyOrphaned, $duplicateByName, $duplicateByMail)
    }

    $summaryLines += ''
    $summaryLines += '## Decision Matrix (Cleanup Recommendations)'
    $summaryLines += ''
    $summaryLines += '| GroupId | GroupDisplayName | CleanupRecommendation | RecommendationReason | RequiredValidationStep | ValidationOwner |'
    $summaryLines += '|---|---|---|---|---|---|'
    foreach ($group in ($effectiveSecurityGroups | Sort-Object GroupDisplayName, GroupId)) {
        $groupId = [string]$group.GroupId
        if ([string]::IsNullOrWhiteSpace($groupId)) { continue }

        $groupDisplayName = ([string]$group.GroupDisplayName) -replace '\|', '\\|'
        $recommendation = ([string]$group.CleanupRecommendation) -replace '\|', '\\|'
        $reason = ([string]$group.RecommendationReason) -replace '\|', '\\|'
        $validationStep = ([string]$group.RequiredValidationStep) -replace '\|', '\\|'
        $validationOwnerVal = ([string]$group.ValidationOwner) -replace '\|', '\\|'

        $summaryLines += ('| {0} | {1} | {2} | {3} | {4} | {5} |' -f $groupId, $groupDisplayName, $recommendation, $reason, $validationStep, $validationOwnerVal)
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

    $hygieneRows = @(
        $effectiveSecurityGroups |
        Sort-Object GroupDisplayName, GroupId |
        ForEach-Object {
            [pscustomobject]@{
                GroupId                      = [string]$_.GroupId
                GroupDisplayName             = [string]$_.GroupDisplayName
                CreatedDateTime              = [string]$_.CreatedDateTime
                IsCloudOnly                  = [bool]$_.IsCloudOnly
                IsOnPremSynced               = [bool]$_.IsOnPremSynced
                OnPremisesSyncEnabled        = [bool]$_.OnPremisesSyncEnabled
                OnPremisesSecurityIdentifier = [string]$_.OnPremisesSecurityIdentifier
                Mail                         = [string]$_.Mail
                MailEnabled                  = [bool]$_.MailEnabled
                OwnerCount                   = [int]$_.OwnerCount
                MemberCount                  = [int]$_.MemberCount
                ParentGroupCount             = [int]$_.ParentGroupCount
                ChildGroupCount              = [int]$_.ChildGroupCount
                NoOwners                     = [bool]$_.NoOwners
                NoMembers                    = [bool]$_.NoMembers
                NoUsageEvidence              = [bool]$_.NoUsageEvidence
                PotentiallyOrphaned          = [bool]$_.PotentiallyOrphaned
                DuplicateByName              = [bool]$_.DuplicateByName
                DuplicateByMail              = [bool]$_.DuplicateByMail
                CleanupRecommendation        = [string]$_.CleanupRecommendation
                RecommendationReason         = [string]$_.RecommendationReason
                RequiredValidationStep       = [string]$_.RequiredValidationStep
                ValidationOwner              = [string]$_.ValidationOwner
            }
        }
    )

    $orphanCandidates = @($hygieneRows | Where-Object { $_.PotentiallyOrphaned })
    $duplicateCandidates = @($hygieneRows | Where-Object { $_.DuplicateByName -or $_.DuplicateByMail })
    $nestedRows = @(
        $effectiveSecurityGroups |
        Sort-Object GroupDisplayName, GroupId |
        ForEach-Object {
            [pscustomobject]@{
                GroupId          = [string]$_.GroupId
                GroupDisplayName = [string]$_.GroupDisplayName
                ParentGroupCount = [int]$_.ParentGroupCount
                ChildGroupCount  = [int]$_.ChildGroupCount
                IsNestedChild    = [bool]$_.IsNestedChild
                IsNestedParent   = [bool]$_.IsNestedParent
            }
        }
    )

    $hygieneRows | Export-Csv -Path $hygieneCsvPath -NoTypeInformation -Encoding UTF8
    $orphanCandidates | Export-Csv -Path $orphanCsvPath -NoTypeInformation -Encoding UTF8
    $duplicateCandidates | Export-Csv -Path $duplicateCsvPath -NoTypeInformation -Encoding UTF8
    $nestedRows | Export-Csv -Path $nestedCsvPath -NoTypeInformation -Encoding UTF8

    $decisionRows = @(
        $hygieneRows |
        Sort-Object @{Expression = {
                switch ($_.CleanupRecommendation) {
                    'RemoveCandidate' { 0 }
                    'Review' { 1 }
                    default { 2 }
                }
            }
        }, GroupDisplayName |
        Select-Object GroupId, GroupDisplayName, CreatedDateTime, IsCloudOnly, IsOnPremSynced, OwnerCount, MemberCount, NoUsageEvidence, PotentiallyOrphaned, DuplicateByName, DuplicateByMail, CleanupRecommendation, RecommendationReason, RequiredValidationStep, ValidationOwner
    )
    $decisionRows | Export-Csv -Path $decisionCsvPath -NoTypeInformation -Encoding UTF8

    Set-Content -Path $mdPath -Value $summaryLines -Encoding UTF8

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

    $reportTimestamp = (Get-Date).ToUniversalTime().ToString('u')
    $removeCandidateCount = @($decisionRows | Where-Object { $_.CleanupRecommendation -eq 'RemoveCandidate' }).Count
    $reviewCount = @($decisionRows | Where-Object { $_.CleanupRecommendation -eq 'Review' }).Count
    $keepCount = @($decisionRows | Where-Object { $_.CleanupRecommendation -eq 'Keep' }).Count

    $css = @'
<style>
  /* Telekom Magenta365 Theme - Corporate Branding */
  *, *::before, *::after { box-sizing: border-box; }
  body { 
    font-family: "TeleNeoWeb", "Segoe UI", system-ui, Arial, sans-serif; 
    font-size: 14px; 
    background: #F5F6F8; 
    color: #262626; 
    margin: 0; 
    padding: 0; 
    line-height: 1.5;
  }
  header { 
    background: linear-gradient(135deg, #E20074 0%, #C51162 100%); 
    color: #fff; 
    padding: 24px 32px 18px; 
    box-shadow: 0 2px 8px rgba(226,0,116,0.2);
  }
  header h1 { 
    margin: 0 0 6px; 
    font-size: 26px; 
    font-weight: 700; 
    letter-spacing: -0.3px;
  }
  header p { 
    margin: 0; 
    font-size: 13px; 
    color: rgba(255,255,255,0.9); 
    font-weight: 400;
  }
  nav { 
    background: #262626; 
    padding: 0 32px; 
    display: flex; 
    flex-wrap: wrap; 
    gap: 4px; 
    box-shadow: 0 1px 4px rgba(0,0,0,0.1);
  }
  nav a { 
    color: #D0D0D0; 
    text-decoration: none; 
    font-size: 12.5px; 
    padding: 10px 14px; 
    display: inline-block; 
    border-radius: 4px 4px 0 0; 
    transition: all 0.2s ease;
    font-weight: 500;
  }
  nav a:hover { 
    background: #E20074; 
    color: #fff; 
    transform: translateY(-1px);
  }
  .summary-bar { 
    display: flex; 
    gap: 18px; 
    padding: 20px 32px; 
    background: #FFFFFF; 
    border-bottom: 1px solid #E6E6E6; 
    flex-wrap: wrap; 
  }
  .stat { 
    background: #FFF0F7; 
    border-left: 4px solid #E20074; 
    padding: 12px 20px; 
    border-radius: 8px; 
    min-width: 170px; 
    box-shadow: 0 1px 3px rgba(0,0,0,0.06);
    transition: transform 0.2s ease;
  }
  .stat:hover { transform: translateY(-2px); box-shadow: 0 2px 6px rgba(0,0,0,0.1); }
  .stat.danger { border-left-color: #E74C3C; background: #FFF5F5; }
  .stat.warn   { border-left-color: #F39C12; background: #FFFBF0; }
  .stat.ok     { border-left-color: #27AE60; background: #F0FFF4; }
  .stat .val { 
    font-size: 28px; 
    font-weight: 700; 
    line-height: 1; 
    color: #262626;
  }
  .stat .lbl { 
    font-size: 11px; 
    color: #666; 
    margin-top: 4px; 
    text-transform: uppercase; 
    letter-spacing: 0.6px; 
    font-weight: 600;
  }
  main { 
    padding: 28px 32px 40px; 
    max-width: 1600px; 
    margin: 0 auto;
  }
  section { 
    background: #FFFFFF; 
    border-radius: 12px; 
    box-shadow: 0 2px 8px rgba(0,0,0,0.06); 
    margin-bottom: 32px; 
    overflow: hidden; 
    border: 1px solid #F0F0F0;
  }
  section h2 { 
    margin: 0; 
    padding: 16px 24px; 
    font-size: 16px; 
    font-weight: 700; 
    background: linear-gradient(90deg, #F8F8F8 0%, #FAFAFA 100%); 
    border-bottom: 2px solid #E20074; 
    color: #262626;
    letter-spacing: -0.2px;
  }
  table { 
    border-collapse: collapse; 
    width: 100%; 
    font-size: 13px; 
  }
  th { 
    background: #F5F5F5; 
    color: #262626; 
    font-weight: 700; 
    padding: 11px 14px; 
    text-align: left; 
    border-bottom: 2px solid #E20074; 
    position: sticky; 
    top: 0; 
    font-size: 12px;
    text-transform: uppercase;
    letter-spacing: 0.4px;
  }
  td { 
    padding: 10px 14px; 
    border-bottom: 1px solid #F0F0F0; 
    vertical-align: top; 
    word-break: break-word; 
    color: #4A4A4A;
  }
  tr:last-child td { border-bottom: none; }
  tr:hover td { background: #FFF9FC; }
  tr.risk-high td { background: #FFF0F0; }
  tr.risk-high:hover td { background: #FFE4E4; }
  tr.risk-review td { background: #FFFBF0; }
  tr.risk-review:hover td { background: #FFF3D8; }
  tr.risk-keep td { background: #F0FFF4; }
  tr.risk-keep:hover td { background: #E3FCED; }
  .badge { 
    display: inline-block; 
    padding: 3px 10px; 
    border-radius: 14px; 
    font-size: 11px; 
    font-weight: 700; 
    text-transform: uppercase;
    letter-spacing: 0.3px;
  }
  .badge-danger { background: #FFE4E4; color: #C0392B; border: 1px solid #F5C6CB; }
  .badge-warn   { background: #FFF3CD; color: #856404; border: 1px solid #FFEAA7; }
  .badge-ok     { background: #D4EDDA; color: #155724; border: 1px solid #C3E6CB; }
  .badge-info   { background: #FFF0F7; color: #8B0049; border: 1px solid #FFD6ED; }
  .manual-hint  { 
    background: #FFFDE7; 
    border-left: 4px solid #F39C12; 
    padding: 12px 16px; 
    font-size: 12.5px; 
    color: #555; 
    margin: 12px 0; 
    border-radius: 0 6px 6px 0; 
    line-height: 1.6;
  }
  @media (max-width: 768px) {
    header, nav, .summary-bar, main { padding-left: 16px; padding-right: 16px; }
    .summary-bar { gap: 12px; }
    .stat { min-width: 140px; padding: 10px 16px; }
    section h2 { font-size: 14px; padding: 14px 18px; }
    th, td { padding: 8px 10px; font-size: 12px; }
  }
</style>
'@

    $navLinks = @(
        'Coverage Summary', 'Security Groups and Usage', 'Hygiene and Cleanup Indicators',
        'Potentially Orphaned Groups', 'Duplicate Candidates',
        'Decision Matrix (Cleanup Recommendations)', 'Evidence'
    ) | ForEach-Object {
        $id = ($_ -replace '[^a-zA-Z0-9]', '-').ToLower() -replace '-+', '-' -replace '^-|-$', ''
        '<a href="#{0}">{1}</a>' -f $id, $_
    }
    $navHtml = '<nav>' + ($navLinks -join '') + '</nav>'

    $evidenceCount = $evidenceViewModel.Count
    $summaryBarHtml = @"
<div class="summary-bar">
  <div class="stat danger"><div class="val">$removeCandidateCount</div><div class="lbl">Remove Candidates</div></div>
  <div class="stat warn">  <div class="val">$reviewCount</div><div class="lbl">Review Required</div></div>
  <div class="stat ok">   <div class="val">$keepCount</div><div class="lbl">Keep</div></div>
  <div class="stat">      <div class="val">$evidenceCount</div><div class="lbl">Evidence Rows</div></div>
</div>
"@

    # Helper: wrap a ConvertTo-Html fragment and add an id to the h2
    function Add-SectionId {
        param([string]$Html)
        $Html -replace '<h2>(.*?)</h2>', {
            $title = $_.Groups[1].Value
            $id = ($title -replace '[^a-zA-Z0-9]', '-').ToLower() -replace '-+', '-' -replace '^-|-$', ''
            "<h2 id=`"$id`">$title</h2>"
        }
    }

    $groupUsageHtml = Add-SectionId ($securityGroupUsageRows | ConvertTo-Html -Fragment -PreContent '<h2>Security Groups and Usage</h2>')
    $hygieneHtml = Add-SectionId ($hygieneRows | ConvertTo-Html -Fragment -PreContent '<h2>Hygiene and Cleanup Indicators</h2>')
    $orphanHtml = Add-SectionId ($orphanCandidates | ConvertTo-Html -Fragment -PreContent '<h2>Potentially Orphaned Groups</h2>')
    $duplicateHtml = Add-SectionId ($duplicateCandidates | ConvertTo-Html -Fragment -PreContent '<h2>Duplicate Candidates</h2>')
    $decisionHtmlRaw = Add-SectionId ($decisionRows | ConvertTo-Html -Fragment -PreContent '<h2>Decision Matrix (Cleanup Recommendations)</h2>')
    $evidenceHtml = Add-SectionId ($evidenceViewModel | ConvertTo-Html -Fragment -PreContent '<h2>Evidence</h2>')
    $coverageHtmlFmt = Add-SectionId ($Coverage | Select-Object Workload, Capability, Status, Findings | ConvertTo-Html -Fragment -PreContent '<h2>Coverage Summary</h2>')

    # Wrap each section in a <section> card
    function Wrap-Section { param([string]$Html) '<section>' + $Html + '</section>' }

    $riskJs = @'
<script>
(function(){
  var tables = document.querySelectorAll('table');
  tables.forEach(function(tbl){
    var headers = tbl.querySelectorAll('th');
    var colIdx = -1;
    headers.forEach(function(th, i){ if(th.textContent.trim() === 'CleanupRecommendation') colIdx = i; });
    if(colIdx < 0) return;
    tbl.querySelectorAll('tbody tr').forEach(function(row){
      var cell = row.cells[colIdx];
      if(!cell) return;
      var v = cell.textContent.trim();
      if(v === 'RemoveCandidate') row.className = 'risk-high';
      else if(v === 'Review') row.className = 'risk-review';
      else if(v === 'Keep') row.className = 'risk-keep';
    });
  });
})();
</script>
'@

    $headerHtml = "<header><h1>Security Group Usage Report</h1><p>Generated (UTC): $reportTimestamp &nbsp;|&nbsp; Graph enabled: $GraphEnabled</p></header>"

    @(
        "<!DOCTYPE html><html lang=`"en`"><head><meta charset=`"utf-8`" /><meta name=`"viewport`" content=`"width=device-width`" /><title>Security Group Usage Report</title>$css</head><body>"
        $headerHtml
        $navHtml
        $summaryBarHtml
        '<main>'
        (Wrap-Section $coverageHtmlFmt)
        (Wrap-Section $groupUsageHtml)
        (Wrap-Section $hygieneHtml)
        (Wrap-Section $orphanHtml)
        (Wrap-Section $duplicateHtml)
        (Wrap-Section $decisionHtmlRaw)
        (Wrap-Section $evidenceHtml)
        '</main>'
        $riskJs
        '</body></html>'
    ) | Set-Content -Path $htmlPath -Encoding UTF8

    return [pscustomobject]@{
        JsonPath         = $jsonPath
        CsvPath          = $csvPath
        HygieneCsvPath   = $hygieneCsvPath
        OrphanCsvPath    = $orphanCsvPath
        DuplicateCsvPath = $duplicateCsvPath
        NestedCsvPath    = $nestedCsvPath
        DecisionCsvPath  = $decisionCsvPath
        MarkdownPath     = $mdPath
        HtmlPath         = $htmlPath
    }
}
