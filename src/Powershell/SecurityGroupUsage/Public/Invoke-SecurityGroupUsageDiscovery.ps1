function Invoke-SecurityGroupUsageDiscovery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = (Join-Path (Get-Location) ("out/SecurityGroupUsage/{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))),

        [Parameter(Mandatory = $false)]
        [switch]$SkipGraph,

        [Parameter(Mandatory = $false)]
        [string[]]$Scopes = @(
            'Directory.Read.All',
            'Group.Read.All',
            'Policy.Read.All',
            'RoleManagement.Read.Directory',
            'DeviceManagementApps.Read.All',
            'DeviceManagementConfiguration.Read.All',
            'Application.Read.All'
        ),

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    Write-Host ''
    Write-Host 'Security Group Usage Discovery' -ForegroundColor Cyan
    Write-Host ('-' * 60) -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  [1/4] Loading workload catalog...' -ForegroundColor DarkGray -NoNewline
    $catalog = Get-SguCatalog
    $matrix = New-SguWorkloadMatrix -Catalog $catalog
    Write-Host (' {0} workloads defined' -f $catalog.Count) -ForegroundColor Green
    Write-Host ''

    $graphEnabled = -not $SkipGraph.IsPresent
    $evidenceBundle = [pscustomobject]@{
        Evidence       = @()
        Coverage       = @()
        Telemetry      = @()
        SecurityGroups = @()
    }

    if ($graphEnabled) {
        Write-Host '  [2/4] Connecting to Microsoft Graph...' -ForegroundColor DarkGray -NoNewline
        Connect-SguGraph -Scopes $Scopes
        Write-Host ' connected' -ForegroundColor Green
        Write-Host ''
        Write-Host '  [3/4] Collecting evidence from workloads...' -ForegroundColor DarkGray
        $evidenceBundle = Get-SguGraphEvidence -WorkloadMatrix $matrix
        Write-Host ''
        Write-Host ('        Total: {0} evidence row(s) across {1} security group(s)' -f $evidenceBundle.Evidence.Count, $evidenceBundle.SecurityGroups.Count) -ForegroundColor Green
        Write-Host ''
    }
    else {
        Write-Host '  [2/4] Graph connection skipped (-SkipGraph)' -ForegroundColor DarkYellow
        Write-Host '  [3/4] Evidence collection skipped (-SkipGraph)' -ForegroundColor DarkYellow
        Write-Host ''
        $coverage = foreach ($entry in $matrix) {
            [pscustomobject]@{
                WorkloadId = $entry.Id
                Workload   = $entry.UsageArea
                Capability = $entry.Capability
                Status     = 'Skipped'
                Findings   = 0
                Message    = 'Graph collection skipped by request.'
            }
        }

        $evidenceBundle = [pscustomobject]@{
            Evidence       = @()
            Coverage       = @($coverage)
            Telemetry      = @()
            SecurityGroups = @()
        }
    }

    Write-Host '  [4/4] Writing output files...' -ForegroundColor DarkGray -NoNewline
    $outFiles = Write-SguOutputs -OutputPath $OutputPath -Catalog $catalog -Matrix $matrix -Evidence $evidenceBundle.Evidence -Coverage $evidenceBundle.Coverage -Telemetry $evidenceBundle.Telemetry -SecurityGroups $evidenceBundle.SecurityGroups -GraphEnabled $graphEnabled
    Write-Host ' done' -ForegroundColor Green
    Write-Host ''
    Write-Host ('-' * 60) -ForegroundColor DarkGray
    Write-Host 'Discovery completed.' -ForegroundColor Green
    Write-Host ('  Catalog entries : {0}' -f $catalog.Count) -ForegroundColor Cyan
    Write-Host ('  Evidence rows   : {0}' -f $evidenceBundle.Evidence.Count) -ForegroundColor Cyan
    Write-Host ('  Output folder   : {0}' -f $OutputPath) -ForegroundColor Cyan
    Write-Host ''
    Write-Host ('JSON report     : {0}' -f $outFiles.JsonPath) -ForegroundColor DarkGray
    Write-Host ('Markdown report : {0}' -f $outFiles.MarkdownPath) -ForegroundColor DarkGray
    Write-Host ('CSV mapping     : {0}' -f $outFiles.CsvPath) -ForegroundColor DarkGray
    Write-Host ('CSV hygiene     : {0}' -f $outFiles.HygieneCsvPath) -ForegroundColor DarkGray
    Write-Host ('CSV orphans     : {0}' -f $outFiles.OrphanCsvPath) -ForegroundColor DarkGray
    Write-Host ('CSV duplicates  : {0}' -f $outFiles.DuplicateCsvPath) -ForegroundColor DarkGray
    Write-Host ('CSV nested map  : {0}' -f $outFiles.NestedCsvPath) -ForegroundColor DarkGray
    Write-Host ('CSV decisions   : {0}' -f $outFiles.DecisionCsvPath) -ForegroundColor DarkGray
    Write-Host ('HTML report     : {0}' -f $outFiles.HtmlPath) -ForegroundColor DarkGray

    if ($PassThru.IsPresent) {
        return [pscustomobject]@{
            Catalog        = $catalog
            WorkloadMatrix = $matrix
            Evidence       = $evidenceBundle.Evidence
            Coverage       = $evidenceBundle.Coverage
            Telemetry      = $evidenceBundle.Telemetry
            SecurityGroups = $evidenceBundle.SecurityGroups
            Output         = $outFiles
        }
    }
}
