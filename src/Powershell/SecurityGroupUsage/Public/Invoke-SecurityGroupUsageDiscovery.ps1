function Invoke-SecurityGroupUsageDiscovery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = (Join-Path (Get-Location) 'out/SecurityGroupUsage'),

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
        [switch]$PassThru,

        # --- Authentication (only used when -SkipGraph is NOT set) ---

        # If omitted, the cmdlet prompts interactively at run time.
        [Parameter(Mandatory = $false)]
        [ValidateSet('WAM', 'DeviceCode', 'ClientCredentials')]
        [string]$AuthMethod,

        # Required when AuthMethod = 'ClientCredentials'
        [Parameter(Mandatory = $false)]
        [string]$TenantId,

        [Parameter(Mandatory = $false)]
        [string]$ClientId,

        # Accepts a SecureString. Use: ConvertTo-SecureString 'secret' -AsPlainText -Force
        [Parameter(Mandatory = $false)]
        [SecureString]$ClientSecret
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    Test-SguPrerequisites | Out-Null

    $timestampSegment = Get-Date -Format 'yyyy-MM-dd-HH_mm'
    $tenantSegment = 'UnknownTenant'

    $toSafePathSegment = {
        param([string]$Value)

        $candidate = [string]$Value
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            return 'UnknownTenant'
        }

        $candidate = $candidate.Trim().TrimEnd('.')
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            return 'UnknownTenant'
        }

        $invalidChars = [System.IO.Path]::GetInvalidFileNameChars() + [char[]]@('/', '\\')
        $invalidClass = [Regex]::Escape(($invalidChars -join ''))
        $safe = [Regex]::Replace($candidate, ('[{0}]' -f $invalidClass), '_')
        $safe = $safe.Trim().TrimEnd('.')

        if ([string]::IsNullOrWhiteSpace($safe)) {
            return 'UnknownTenant'
        }

        return $safe
    }

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
        # Step 2: Resolve auth method, prompt if not pre-supplied
        Write-Host '  [2/4] Connecting to Microsoft Graph...' -ForegroundColor DarkGray
        Write-Host ''

        $resolvedAuthMethod = $AuthMethod
        $resolvedTenantId = $TenantId
        $resolvedClientId = $ClientId
        $resolvedClientSecret = $ClientSecret

        if ([string]::IsNullOrWhiteSpace($resolvedAuthMethod)) {
            Write-Host '        Select authentication method:' -ForegroundColor Cyan
            Write-Host '          [1] WAM (default)        (system web account manager)' -ForegroundColor White
            Write-Host '          [2] Device Code Flow     (browser-based)' -ForegroundColor White
            Write-Host '          [3] Client ID + Secret   (app registration)' -ForegroundColor White
            Write-Host ''
            $choice = $null
            while ($choice -notin '', '1', '2', '3') {
                $choice = (Read-Host '        Choice [1-3] (Enter = 1)').Trim()
            }
            switch ($choice) {
                '' { $resolvedAuthMethod = 'WAM' }
                '1' { $resolvedAuthMethod = 'WAM' }
                '2' { $resolvedAuthMethod = 'DeviceCode' }
                '3' { $resolvedAuthMethod = 'ClientCredentials' }
            }
            Write-Host ''
        }

        if ($resolvedAuthMethod -eq 'ClientCredentials') {
            if ([string]::IsNullOrWhiteSpace($resolvedTenantId)) {
                $resolvedTenantId = (Read-Host '        TenantId').Trim()
            }
            if ([string]::IsNullOrWhiteSpace($resolvedClientId)) {
                $resolvedClientId = (Read-Host '        ClientId').Trim()
            }
            if ($null -eq $resolvedClientSecret) {
                $resolvedClientSecret = Read-Host '        ClientSecret' -AsSecureString
            }
        }

        try {
            Connect-SguGraph -Scopes $Scopes `
                -AuthMethod $resolvedAuthMethod `
                -TenantId $resolvedTenantId `
                -ClientId $resolvedClientId `
                -ClientSecret $resolvedClientSecret

            $tenantSegment = if ([string]::IsNullOrWhiteSpace($resolvedTenantId)) { 'UnknownTenant' } else { $resolvedTenantId }
            try {
                $orgResponse = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/organization?$select=displayName,id'
                $orgItems = @()

                if ($orgResponse -is [System.Collections.IDictionary] -and $orgResponse.Contains('value')) {
                    $orgItems = @($orgResponse['value'])
                }
                elseif ($null -ne $orgResponse.value) {
                    $orgItems = @($orgResponse.value)
                }

                if ($orgItems.Count -gt 0) {
                    $orgDisplayName = [string]$orgItems[0].displayName
                    $orgId = [string]$orgItems[0].id

                    if (-not [string]::IsNullOrWhiteSpace($orgDisplayName)) {
                        $tenantSegment = $orgDisplayName
                    }
                    elseif (-not [string]::IsNullOrWhiteSpace($orgId)) {
                        $tenantSegment = $orgId
                    }
                }
            }
            catch {
                Write-Verbose ('Could not resolve tenant display name. Falling back to TenantId. Error: {0}' -f $_.Exception.Message)
            }

            Write-Host '        Connected' -ForegroundColor Green
            Write-Host ''

            # Step 3: Collect evidence
            Write-Host '  [3/4] Collecting evidence from workloads...' -ForegroundColor DarkGray
            $evidenceBundle = Get-SguGraphEvidence -WorkloadMatrix $matrix
            Write-Host ''
            Write-Host ('        Total: {0} evidence row(s) across {1} security group(s)' -f $evidenceBundle.Evidence.Count, $evidenceBundle.SecurityGroups.Count) -ForegroundColor Green
            Write-Host ''
        }
        finally {
            Write-Verbose 'Disconnecting from Microsoft Graph (process session)...'
            Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
            Write-Host '        Graph session closed.' -ForegroundColor DarkGray
            Write-Host ''
        }
    }
    else {
        if (-not [string]::IsNullOrWhiteSpace($TenantId)) {
            $tenantSegment = $TenantId
        }
        else {
            $tenantSegment = 'NoGraph'
        }

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

    $resolvedOutputPath = Join-Path (Join-Path $OutputPath (& $toSafePathSegment $tenantSegment)) $timestampSegment

    Write-Host '  [4/4] Writing output files...' -ForegroundColor DarkGray -NoNewline
    $outFiles = Write-SguOutputs -OutputPath $resolvedOutputPath -Catalog $catalog -Matrix $matrix -Evidence $evidenceBundle.Evidence -Coverage $evidenceBundle.Coverage -Telemetry $evidenceBundle.Telemetry -SecurityGroups $evidenceBundle.SecurityGroups -GraphEnabled $graphEnabled
    Write-Host ' done' -ForegroundColor Green
    Write-Host ''
    Write-Host ('-' * 60) -ForegroundColor DarkGray
    Write-Host 'Discovery completed.' -ForegroundColor Green
    Write-Host ('  Catalog entries : {0}' -f $catalog.Count) -ForegroundColor Cyan
    Write-Host ('  Evidence rows   : {0}' -f $evidenceBundle.Evidence.Count) -ForegroundColor Cyan
    Write-Host ('  Output folder   : {0}' -f $resolvedOutputPath) -ForegroundColor Cyan
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
