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
            'Application.Read.All'
        ),

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    Write-Verbose 'Loading internal workload and endpoint catalog...'
    $catalog = Get-SguCatalog
    $matrix = New-SguWorkloadMatrix -Catalog $catalog

    $graphEnabled = -not $SkipGraph.IsPresent
    $evidenceBundle = [pscustomobject]@{
        Evidence       = @()
        Coverage       = @()
        Telemetry      = @()
        SecurityGroups = @()
    }

    if ($graphEnabled) {
        Write-Verbose 'Connecting to Graph and collecting evidence...'
        Connect-SguGraph -Scopes $Scopes
        $evidenceBundle = Get-SguGraphEvidence -WorkloadMatrix $matrix
    }
    else {
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

    $outFiles = Write-SguOutputs -OutputPath $OutputPath -Catalog $catalog -Matrix $matrix -Evidence $evidenceBundle.Evidence -Coverage $evidenceBundle.Coverage -Telemetry $evidenceBundle.Telemetry -SecurityGroups $evidenceBundle.SecurityGroups -GraphEnabled $graphEnabled

    Write-Host ''
    Write-Host 'Security Group Usage Discovery completed.' -ForegroundColor Green
    Write-Host ('Catalog entries : {0}' -f $catalog.Count) -ForegroundColor Cyan
    Write-Host ('Evidence rows   : {0}' -f $evidenceBundle.Evidence.Count) -ForegroundColor Cyan
    Write-Host ('Output folder   : {0}' -f $OutputPath) -ForegroundColor Cyan
    Write-Host ('JSON report     : {0}' -f $outFiles.JsonPath) -ForegroundColor DarkGray
    Write-Host ('Markdown report : {0}' -f $outFiles.MarkdownPath) -ForegroundColor DarkGray
    Write-Host ('CSV mapping     : {0}' -f $outFiles.CsvPath) -ForegroundColor DarkGray
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
