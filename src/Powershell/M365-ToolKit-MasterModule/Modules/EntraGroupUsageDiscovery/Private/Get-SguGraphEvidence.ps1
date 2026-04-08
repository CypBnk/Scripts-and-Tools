function Get-SguGraphEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$WorkloadMatrix
    )

    $evidence = New-Object System.Collections.Generic.List[object]
    $telemetry = New-Object System.Collections.Generic.List[object]
    $coverage = New-Object System.Collections.Generic.List[object]
    $securityGroups = New-Object System.Collections.Generic.List[object]
    $groupDisplayNameById = @{}
    $roleDisplayNameById = @{}

    function Get-SguValue {
        param(
            [Parameter(Mandatory = $false)]
            [object]$Object,

            [Parameter(Mandatory = $true)]
            [string]$Name
        )

        if ($null -eq $Object) {
            return $null
        }

        if ($Object -is [System.Collections.IDictionary]) {
            if ($Object.Contains($Name)) {
                return $Object[$Name]
            }

            return $null
        }

        $property = $Object.PSObject.Properties.Match($Name) | Select-Object -First 1
        if ($null -ne $property) {
            return $property.Value
        }

        return $null
    }

    function Add-Telemetry {
        param(
            [string]$Workload,
            [string]$Endpoint,
            [datetime]$Start,
            [int]$ItemCount,
            [string]$Status,
            [string]$ErrorText
        )

        $telemetry.Add([pscustomobject]@{
                Workload     = $Workload
                Endpoint     = $Endpoint
                StartedAtUtc = $Start.ToUniversalTime().ToString('o')
                DurationMs   = [int]((Get-Date).ToUniversalTime().Subtract($Start.ToUniversalTime()).TotalMilliseconds)
                ItemCount    = $ItemCount
                Status       = $Status
                Error        = $ErrorText
            })
    }

    function Add-Evidence {
        param(
            [object]$Entry,
            [string]$GroupId,
            [string]$GroupDisplayName,
            [string]$ObjectType,
            [string]$ObjectId,
            [string]$ObjectName,
            [string]$AssignmentMode,
            [string]$SourceType,
            [string]$SourceLink
        )

        $evidence.Add([pscustomobject]@{
                WorkloadId       = $Entry.Id
                Workload         = $Entry.UsageArea
                Section          = $Entry.Section
                GroupId          = $GroupId
                GroupDisplayName = $GroupDisplayName
                ObjectType       = $ObjectType
                ObjectId         = $ObjectId
                ObjectName       = $ObjectName
                AssignmentMode   = $AssignmentMode
                SourceType       = $SourceType
                SourceLink       = $SourceLink
            })
    }

    function Resolve-GroupDisplayName {
        param(
            [Parameter(Mandatory = $false)]
            [string]$GroupId
        )

        if ([string]::IsNullOrWhiteSpace($GroupId)) {
            return ''
        }

        if ($groupDisplayNameById.ContainsKey($GroupId)) {
            return [string]$groupDisplayNameById[$GroupId]
        }

        return ''
    }

    function Resolve-RoleDisplayName {
        param(
            [Parameter(Mandatory = $false)]
            [string]$RoleDefinitionId
        )

        if ([string]::IsNullOrWhiteSpace($RoleDefinitionId)) {
            return ''
        }

        if ($roleDisplayNameById.ContainsKey($RoleDefinitionId)) {
            return [string]$roleDisplayNameById[$RoleDefinitionId]
        }

        return ''
    }

    Write-Host '        [group-inventory] Fetching security groups with hygiene metrics...' -ForegroundColor DarkGray
    try {
        $groupsStart = Get-Date
        $groupsEndpoint = 'https://graph.microsoft.com/v1.0/groups?$select=id,displayName,description,mail,securityEnabled,mailEnabled,groupTypes,createdDateTime,onPremisesSyncEnabled,onPremisesSecurityIdentifier'
        $allGroups = Invoke-SguGraphPagedRequest -Uri $groupsEndpoint
        $securityGroupCount = 0

        $securityGroupRecords = New-Object System.Collections.Generic.List[object]
        $nameCounts = @{}
        $mailCounts = @{}

        foreach ($group in $allGroups) {
            $groupId = [string](Get-SguValue -Object $group -Name 'id')
            if ([string]::IsNullOrWhiteSpace($groupId)) { continue }

            $groupDisplayName = [string](Get-SguValue -Object $group -Name 'displayName')
            $groupDisplayNameById[$groupId] = $groupDisplayName

            $isSecurityEnabled = [bool](Get-SguValue -Object $group -Name 'securityEnabled')
            if (-not $isSecurityEnabled) { continue }

            $groupTypesRaw = @((Get-SguValue -Object $group -Name 'groupTypes'))
            $groupTypes = @($groupTypesRaw | ForEach-Object { [string]$_ })
            $mail = [string](Get-SguValue -Object $group -Name 'mail')
            $description = [string](Get-SguValue -Object $group -Name 'description')
            $createdDateTime = [string](Get-SguValue -Object $group -Name 'createdDateTime')
            $onPremisesSyncEnabledRaw = Get-SguValue -Object $group -Name 'onPremisesSyncEnabled'
            $onPremisesSyncEnabled = ($null -ne $onPremisesSyncEnabledRaw) -and [bool]$onPremisesSyncEnabledRaw
            $onPremisesSecurityIdentifier = [string](Get-SguValue -Object $group -Name 'onPremisesSecurityIdentifier')

            $ownerCount = 0
            $memberCount = 0
            $childGroupCount = 0
            $childGroupIds = @()
            $parentGroupCount = 0
            $parentGroupIds = @()

            try {
                $ownersEndpoint = ('https://graph.microsoft.com/v1.0/groups/{0}/owners?$select=id' -f $groupId)
                $owners = Invoke-SguGraphPagedRequest -Uri $ownersEndpoint
                $ownerCount = @($owners).Count
            }
            catch {
                $ownerCount = 0
            }

            try {
                $membersEndpoint = ('https://graph.microsoft.com/v1.0/groups/{0}/members?$select=id' -f $groupId)
                $members = Invoke-SguGraphPagedRequest -Uri $membersEndpoint
                $memberCount = @($members).Count
            }
            catch {
                $memberCount = 0
            }

            try {
                $childGroupsEndpoint = ('https://graph.microsoft.com/v1.0/groups/{0}/members/microsoft.graph.group?$select=id' -f $groupId)
                $childGroups = Invoke-SguGraphPagedRequest -Uri $childGroupsEndpoint
                $childGroupCount = @($childGroups).Count
                $childGroupIds = @($childGroups | ForEach-Object { [string](Get-SguValue -Object $_ -Name 'id') } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            }
            catch {
                $childGroupCount = 0
                $childGroupIds = @()
            }

            try {
                $parentGroupsEndpoint = ('https://graph.microsoft.com/v1.0/groups/{0}/memberOf/microsoft.graph.group?$select=id' -f $groupId)
                $parentGroups = Invoke-SguGraphPagedRequest -Uri $parentGroupsEndpoint
                $parentGroupCount = @($parentGroups).Count
                $parentGroupIds = @($parentGroups | ForEach-Object { [string](Get-SguValue -Object $_ -Name 'id') } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            }
            catch {
                $parentGroupCount = 0
                $parentGroupIds = @()
            }

            $normalizedDisplayName = (($groupDisplayName -replace '\s+', ' ').Trim()).ToLowerInvariant()
            if (-not [string]::IsNullOrWhiteSpace($normalizedDisplayName)) {
                if ($nameCounts.ContainsKey($normalizedDisplayName)) {
                    $nameCounts[$normalizedDisplayName] = [int]$nameCounts[$normalizedDisplayName] + 1
                }
                else {
                    $nameCounts[$normalizedDisplayName] = 1
                }
            }

            $normalizedMail = ($mail.Trim()).ToLowerInvariant()
            if (-not [string]::IsNullOrWhiteSpace($normalizedMail)) {
                if ($mailCounts.ContainsKey($normalizedMail)) {
                    $mailCounts[$normalizedMail] = [int]$mailCounts[$normalizedMail] + 1
                }
                else {
                    $mailCounts[$normalizedMail] = 1
                }
            }

            $securityGroupRecords.Add([pscustomobject]@{
                    GroupId                      = $groupId
                    GroupDisplayName             = $groupDisplayName
                    NormalizedDisplayName        = $normalizedDisplayName
                    Mail                         = $mail
                    Description                  = $description
                    CreatedDateTime              = $createdDateTime
                    OnPremisesSyncEnabled        = $onPremisesSyncEnabled
                    OnPremisesSecurityIdentifier = $onPremisesSecurityIdentifier
                    IsOnPremSynced               = $onPremisesSyncEnabled -or (-not [string]::IsNullOrWhiteSpace($onPremisesSecurityIdentifier))
                    IsCloudOnly                  = -not ($onPremisesSyncEnabled -or (-not [string]::IsNullOrWhiteSpace($onPremisesSecurityIdentifier)))
                    MailEnabled                  = [bool](Get-SguValue -Object $group -Name 'mailEnabled')
                    GroupTypes                   = ($groupTypes -join ';')
                    OwnerCount                   = $ownerCount
                    MemberCount                  = $memberCount
                    HasOwners                    = ($ownerCount -gt 0)
                    HasMembers                   = ($memberCount -gt 0)
                    NoOwners                     = ($ownerCount -eq 0)
                    NoMembers                    = ($memberCount -eq 0)
                    ParentGroupCount             = $parentGroupCount
                    ParentGroupIds               = ($parentGroupIds -join ';')
                    ChildGroupCount              = $childGroupCount
                    ChildGroupIds                = ($childGroupIds -join ';')
                    IsNestedParent               = ($childGroupCount -gt 0)
                    IsNestedChild                = ($parentGroupCount -gt 0)
                    DuplicateByName              = $false
                    DuplicateByMail              = $false
                    NoUsageEvidence              = $false
                    PotentiallyOrphaned          = $false
                })
            $securityGroupCount++
        }

        foreach ($record in $securityGroupRecords) {
            $normalizedDisplayName = [string]$record.NormalizedDisplayName
            $normalizedMail = ([string]$record.Mail).Trim().ToLowerInvariant()

            $duplicateByName = $false
            if (-not [string]::IsNullOrWhiteSpace($normalizedDisplayName) -and $nameCounts.ContainsKey($normalizedDisplayName)) {
                $duplicateByName = [int]$nameCounts[$normalizedDisplayName] -gt 1
            }

            $duplicateByMail = $false
            if (-not [string]::IsNullOrWhiteSpace($normalizedMail) -and $mailCounts.ContainsKey($normalizedMail)) {
                $duplicateByMail = [int]$mailCounts[$normalizedMail] -gt 1
            }

            $securityGroups.Add([pscustomobject]@{
                    GroupId                      = [string]$record.GroupId
                    GroupDisplayName             = [string]$record.GroupDisplayName
                    NormalizedDisplayName        = [string]$record.NormalizedDisplayName
                    Mail                         = [string]$record.Mail
                    Description                  = [string]$record.Description
                    CreatedDateTime              = [string]$record.CreatedDateTime
                    OnPremisesSyncEnabled        = [bool]$record.OnPremisesSyncEnabled
                    OnPremisesSecurityIdentifier = [string]$record.OnPremisesSecurityIdentifier
                    IsOnPremSynced               = [bool]$record.IsOnPremSynced
                    IsCloudOnly                  = [bool]$record.IsCloudOnly
                    MailEnabled                  = [bool]$record.MailEnabled
                    GroupTypes                   = [string]$record.GroupTypes
                    OwnerCount                   = [int]$record.OwnerCount
                    MemberCount                  = [int]$record.MemberCount
                    HasOwners                    = [bool]$record.HasOwners
                    HasMembers                   = [bool]$record.HasMembers
                    NoOwners                     = [bool]$record.NoOwners
                    NoMembers                    = [bool]$record.NoMembers
                    ParentGroupCount             = [int]$record.ParentGroupCount
                    ParentGroupIds               = [string]$record.ParentGroupIds
                    ChildGroupCount              = [int]$record.ChildGroupCount
                    ChildGroupIds                = [string]$record.ChildGroupIds
                    IsNestedParent               = [bool]$record.IsNestedParent
                    IsNestedChild                = [bool]$record.IsNestedChild
                    DuplicateByName              = $duplicateByName
                    DuplicateByMail              = $duplicateByMail
                    NoUsageEvidence              = $false
                    PotentiallyOrphaned          = $false
                })
        }

        Write-Host ('        [group-inventory] Done — {0} security group(s) loaded' -f $securityGroups.Count) -ForegroundColor Green
        Add-Telemetry -Workload 'Security Group Directory' -Endpoint $groupsEndpoint -Start $groupsStart -ItemCount $securityGroupCount -Status 'Success' -ErrorText ''
    }
    catch {
        Write-Host '        [group-inventory] Error while fetching groups' -ForegroundColor Red
        Add-Telemetry -Workload 'Security Group Directory' -Endpoint 'https://graph.microsoft.com/v1.0/groups' -Start (Get-Date) -ItemCount 0 -Status 'Error' -ErrorText ([string]$_.Exception.Message)
    }

    $workloadTotal = @($WorkloadMatrix).Count
    $workloadIndex = 0
    foreach ($entry in $WorkloadMatrix) {
        $workloadIndex++
        $progressPct = [int](($workloadIndex / [Math]::Max(1, $workloadTotal)) * 100)
        Write-Progress -Activity 'Collecting Evidence' `
            -Status ('{0}/{1}: {2}' -f $workloadIndex, $workloadTotal, $entry.UsageArea) `
            -PercentComplete $progressPct
        Write-Host ('        [{0}/{1}] {2}...' -f $workloadIndex, $workloadTotal, $entry.UsageArea) -ForegroundColor DarkGray -NoNewline
        $status = 'NotQueryable'
        $errorText = ''
        $beforeCount = $evidence.Count

        if ($entry.Capability -eq 'NotQueryable') {
            $coverage.Add([pscustomobject]@{
                    WorkloadId = $entry.Id
                    Workload   = $entry.UsageArea
                    Capability = $entry.Capability
                    Status     = 'NotQueryable'
                    Findings   = 0
                    Message    = 'No tenant-level Graph evidence collector implemented for this workload.'
                })
            Write-Host ' [NotQueryable]' -ForegroundColor DarkGray
            continue
        }

        try {
            if ($entry.UsageArea -match 'Entra ID Roles') {
                $start = Get-Date
                $endpoint = 'https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments?$select=id,principalId,roleDefinitionId,directoryScopeId'

                if ($roleDisplayNameById.Count -eq 0) {
                    try {
                        $roleDefinitionsEndpoint = 'https://graph.microsoft.com/v1.0/roleManagement/directory/roleDefinitions?$select=id,templateId,displayName'
                        $roleDefinitions = Invoke-SguGraphPagedRequest -Uri $roleDefinitionsEndpoint
                        foreach ($roleDefinition in $roleDefinitions) {
                            $definitionId = [string](Get-SguValue -Object $roleDefinition -Name 'id')
                            $templateId = [string](Get-SguValue -Object $roleDefinition -Name 'templateId')
                            $displayName = [string](Get-SguValue -Object $roleDefinition -Name 'displayName')

                            if (-not [string]::IsNullOrWhiteSpace($definitionId) -and -not [string]::IsNullOrWhiteSpace($displayName)) {
                                $roleDisplayNameById[$definitionId] = $displayName
                            }

                            if (-not [string]::IsNullOrWhiteSpace($templateId) -and -not [string]::IsNullOrWhiteSpace($displayName)) {
                                $roleDisplayNameById[$templateId] = $displayName
                            }
                        }
                    }
                    catch {
                        # If role definition lookup fails, fall back to roleDefinitionId in evidence output.
                    }
                }

                $assignments = Invoke-SguGraphPagedRequest -Uri $endpoint
                $count = 0

                foreach ($assignment in $assignments) {
                    $principalId = [string](Get-SguValue -Object $assignment -Name 'principalId')
                    if ([string]::IsNullOrWhiteSpace($principalId)) { continue }

                    $roleDefinitionId = [string](Get-SguValue -Object $assignment -Name 'roleDefinitionId')
                    $roleDisplayName = Resolve-RoleDisplayName -RoleDefinitionId $roleDefinitionId
                    $roleObjectName = if (-not [string]::IsNullOrWhiteSpace($roleDisplayName)) { $roleDisplayName } else { $roleDefinitionId }

                    $principalEndpoint = ("https://graph.microsoft.com/v1.0/directoryObjects/{0}" -f $principalId)
                    try {
                        $principal = Invoke-MgGraphRequest -Method GET -Uri $principalEndpoint
                        if ([string](Get-SguValue -Object $principal -Name '@odata.type') -eq '#microsoft.graph.group') {
                            Add-Evidence -Entry $entry -GroupId $principalId -GroupDisplayName ([string](Get-SguValue -Object $principal -Name 'displayName')) -ObjectType 'RoleAssignment' -ObjectId ([string](Get-SguValue -Object $assignment -Name 'id')) -ObjectName $roleObjectName -AssignmentMode 'Include' -SourceType 'Graph' -SourceLink $endpoint
                            $count++
                        }
                    }
                    catch {
                        continue
                    }
                }

                Add-Telemetry -Workload $entry.UsageArea -Endpoint $endpoint -Start $start -ItemCount $count -Status 'Success' -ErrorText ''
                $status = 'Queryable'
            }
            elseif ($entry.UsageArea -match 'Conditional Access') {
                $start = Get-Date
                $endpoint = 'https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies?$select=id,displayName,conditions,state'
                $policies = Invoke-SguGraphPagedRequest -Uri $endpoint
                $count = 0

                foreach ($policy in $policies) {
                    $conditions = Get-SguValue -Object $policy -Name 'conditions'
                    $users = Get-SguValue -Object $conditions -Name 'users'
                    if ($null -eq $conditions -or $null -eq $users) { continue }

                    $includeGroups = @((Get-SguValue -Object $users -Name 'includeGroups'))
                    $excludeGroups = @((Get-SguValue -Object $users -Name 'excludeGroups'))

                    foreach ($groupId in $includeGroups) {
                        if (-not [string]::IsNullOrWhiteSpace([string]$groupId) -and [string]$groupId -ne 'All') {
                            Add-Evidence -Entry $entry -GroupId ([string]$groupId) -GroupDisplayName (Resolve-GroupDisplayName -GroupId ([string]$groupId)) -ObjectType 'ConditionalAccessPolicy' -ObjectId ([string](Get-SguValue -Object $policy -Name 'id')) -ObjectName ([string](Get-SguValue -Object $policy -Name 'displayName')) -AssignmentMode 'Include' -SourceType 'Graph' -SourceLink $endpoint
                            $count++
                        }
                    }

                    foreach ($groupId in $excludeGroups) {
                        if (-not [string]::IsNullOrWhiteSpace([string]$groupId) -and [string]$groupId -ne 'All') {
                            Add-Evidence -Entry $entry -GroupId ([string]$groupId) -GroupDisplayName (Resolve-GroupDisplayName -GroupId ([string]$groupId)) -ObjectType 'ConditionalAccessPolicy' -ObjectId ([string](Get-SguValue -Object $policy -Name 'id')) -ObjectName ([string](Get-SguValue -Object $policy -Name 'displayName')) -AssignmentMode 'Exclude' -SourceType 'Graph' -SourceLink $endpoint
                            $count++
                        }
                    }
                }

                Add-Telemetry -Workload $entry.UsageArea -Endpoint $endpoint -Start $start -ItemCount $count -Status 'Success' -ErrorText ''
                $status = 'Queryable'
            }
            elseif ($entry.UsageArea -match 'Group-based Licensing') {
                $start = Get-Date
                $endpoint = 'https://graph.microsoft.com/v1.0/groups?$select=id,displayName,assignedLicenses,securityEnabled'
                $groups = Invoke-SguGraphPagedRequest -Uri $endpoint
                $count = 0

                foreach ($group in $groups) {
                    $assigned = @((Get-SguValue -Object $group -Name 'assignedLicenses'))
                    if ($assigned.Count -gt 0 -and [bool](Get-SguValue -Object $group -Name 'securityEnabled')) {
                        $groupId = [string](Get-SguValue -Object $group -Name 'id')
                        $groupDisplayName = Resolve-GroupDisplayName -GroupId $groupId
                        Add-Evidence -Entry $entry -GroupId $groupId -GroupDisplayName $groupDisplayName -ObjectType 'GroupLicenseAssignment' -ObjectId $groupId -ObjectName $groupDisplayName -AssignmentMode 'Include' -SourceType 'Graph' -SourceLink $endpoint
                        $count++
                    }
                }

                Add-Telemetry -Workload $entry.UsageArea -Endpoint $endpoint -Start $start -ItemCount $count -Status 'Success' -ErrorText ''
                $status = 'Queryable'
            }
            elseif ($entry.UsageArea -match 'Enterprise Applications') {
                $start = Get-Date
                $spEndpoint = 'https://graph.microsoft.com/v1.0/servicePrincipals?$select=id,displayName'
                $servicePrincipals = Invoke-SguGraphPagedRequest -Uri $spEndpoint
                $count = 0

                # Enterprise Applications: show nested progress and verbose diagnostics
                $spTotal = if ($null -eq $servicePrincipals) { 0 } else { $servicePrincipals.Count }
                $spIndex = 0
                Write-Verbose ('    Enterprise Applications: {0} service principal(s) to scan' -f $spTotal)

                foreach ($sp in $servicePrincipals) {
                    $spIndex++
                    $spId = [string](Get-SguValue -Object $sp -Name 'id')
                    $spDisplayName = [string](Get-SguValue -Object $sp -Name 'displayName')
                    if ([string]::IsNullOrWhiteSpace($spId)) { continue }

                    $spDisplay = if (-not [string]::IsNullOrWhiteSpace($spDisplayName)) { $spDisplayName } else { $spId }

                    # Nested visual progress for enterprise app loop
                    $spPercent = [int](($spIndex / [Math]::Max(1, $spTotal)) * 100)
                    Write-Progress -Id 2 -Activity 'Enterprise Applications' -Status ('{0}/{1}: {2}' -f $spIndex, $spTotal, $spDisplay) -PercentComplete $spPercent

                    Write-Verbose ('      Processing service principal {0}/{1}: {2} (id: {3})' -f $spIndex, $spTotal, $spDisplay, $spId)

                    $assignmentsEndpoint = ('https://graph.microsoft.com/v1.0/servicePrincipals/{0}/appRoleAssignedTo?$select=id,principalId,principalType,principalDisplayName' -f $spId)
                    try {
                        $assignments = Invoke-SguGraphPagedRequest -Uri $assignmentsEndpoint
                        foreach ($assignment in $assignments) {
                            $principalType = [string](Get-SguValue -Object $assignment -Name 'principalType')
                            if ($principalType -ne 'Group') { continue }

                            $principalId = [string](Get-SguValue -Object $assignment -Name 'principalId')
                            if ([string]::IsNullOrWhiteSpace($principalId)) { continue }

                            Add-Evidence -Entry $entry `
                                -GroupId $principalId `
                                -GroupDisplayName (Resolve-GroupDisplayName -GroupId $principalId) `
                                -ObjectType 'AppRoleAssignment' `
                                -ObjectId ([string](Get-SguValue -Object $assignment -Name 'id')) `
                                -ObjectName $spDisplayName `
                                -AssignmentMode 'Include' `
                                -SourceType 'Graph' `
                                -SourceLink $assignmentsEndpoint
                            $count++
                        }

                        Write-Verbose ('      Found {0} group assignment(s) for {1}' -f $count, $spDisplay)
                    }
                    catch {
                        Write-Verbose ('      Failed to fetch assignments for {0}: {1}' -f $spDisplay, $_.Exception.Message)
                        continue
                    }
                }

                # Ensure nested progress is completed
                Write-Progress -Id 2 -Activity 'Enterprise Applications' -Completed

                Add-Telemetry -Workload $entry.UsageArea -Endpoint $spEndpoint -Start $start -ItemCount $count -Status 'Success' -ErrorText ''
                $status = 'Queryable'
            }
            elseif ($entry.UsageArea -match 'Intune') {
                $start = Get-Date
                $appsEndpoint = 'https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps?$select=id,displayName'
                $apps = Invoke-SguGraphPagedRequest -Uri $appsEndpoint
                $count = 0

                foreach ($app in $apps) {
                    $appId = [string](Get-SguValue -Object $app -Name 'id')
                    $appDisplayName = [string](Get-SguValue -Object $app -Name 'displayName')
                    if ([string]::IsNullOrWhiteSpace($appId)) { continue }

                    $assignmentsEndpoint = ("https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps/{0}/assignments" -f $appId)
                    $assignments = Invoke-SguGraphPagedRequest -Uri $assignmentsEndpoint
                    foreach ($assignment in $assignments) {
                        $target = Get-SguValue -Object $assignment -Name 'target'
                        if ($null -eq $target) { continue }

                        $groupId = ''
                        $groupId = [string](Get-SguValue -Object $target -Name 'groupId')

                        if (-not [string]::IsNullOrWhiteSpace($groupId)) {
                            Add-Evidence -Entry $entry -GroupId $groupId -GroupDisplayName (Resolve-GroupDisplayName -GroupId $groupId) -ObjectType 'IntuneAppAssignment' -ObjectId ([string](Get-SguValue -Object $assignment -Name 'id')) -ObjectName $appDisplayName -AssignmentMode 'Include' -SourceType 'Graph' -SourceLink $assignmentsEndpoint
                            $count++
                        }
                    }
                }

                Add-Telemetry -Workload $entry.UsageArea -Endpoint $appsEndpoint -Start $start -ItemCount $count -Status 'Success' -ErrorText ''
                $status = 'Queryable'

                # Intune Device Compliance Policies
                try {
                    $complianceStart = Get-Date
                    $complianceEndpoint = 'https://graph.microsoft.com/v1.0/deviceManagement/deviceCompliancePolicies?$select=id,displayName'
                    $compliancePolicies = Invoke-SguGraphPagedRequest -Uri $complianceEndpoint

                    foreach ($policy in $compliancePolicies) {
                        $policyId = [string](Get-SguValue -Object $policy -Name 'id')
                        $policyDisplayName = [string](Get-SguValue -Object $policy -Name 'displayName')
                        if ([string]::IsNullOrWhiteSpace($policyId)) { continue }

                        $policyAssignmentsEndpoint = ('https://graph.microsoft.com/v1.0/deviceManagement/deviceCompliancePolicies/{0}/assignments' -f $policyId)
                        $policyAssignments = Invoke-SguGraphPagedRequest -Uri $policyAssignmentsEndpoint
                        foreach ($assignment in $policyAssignments) {
                            $target = Get-SguValue -Object $assignment -Name 'target'
                            if ($null -eq $target) { continue }

                            $odataType = [string](Get-SguValue -Object $target -Name '@odata.type')
                            if ($odataType -notmatch 'groupAssignmentTarget') { continue }

                            $groupId = [string](Get-SguValue -Object $target -Name 'groupId')
                            if (-not [string]::IsNullOrWhiteSpace($groupId)) {
                                Add-Evidence -Entry $entry `
                                    -GroupId $groupId `
                                    -GroupDisplayName (Resolve-GroupDisplayName -GroupId $groupId) `
                                    -ObjectType 'CompliancePolicyAssignment' `
                                    -ObjectId ([string](Get-SguValue -Object $assignment -Name 'id')) `
                                    -ObjectName $policyDisplayName `
                                    -AssignmentMode (if ($odataType -match 'exclusion') { 'Exclude' } else { 'Include' }) `
                                    -SourceType 'Graph' `
                                    -SourceLink $policyAssignmentsEndpoint
                                $count++
                            }
                        }
                    }
                    Add-Telemetry -Workload ($entry.UsageArea + ' (Compliance)') -Endpoint $complianceEndpoint -Start $complianceStart -ItemCount $count -Status 'Success' -ErrorText ''
                }
                catch {
                    Add-Telemetry -Workload ($entry.UsageArea + ' (Compliance)') -Endpoint 'deviceManagement/deviceCompliancePolicies' -Start (Get-Date) -ItemCount 0 -Status 'Error' -ErrorText ([string]$_.Exception.Message)
                }

                # Intune Device Configuration Profiles
                try {
                    $configStart = Get-Date
                    $configEndpoint = 'https://graph.microsoft.com/v1.0/deviceManagement/deviceConfigurations?$select=id,displayName'
                    $configProfiles = Invoke-SguGraphPagedRequest -Uri $configEndpoint

                    foreach ($profile in $configProfiles) {
                        $profileId = [string](Get-SguValue -Object $profile -Name 'id')
                        $profileDisplayName = [string](Get-SguValue -Object $profile -Name 'displayName')
                        if ([string]::IsNullOrWhiteSpace($profileId)) { continue }

                        $profileAssignmentsEndpoint = ('https://graph.microsoft.com/v1.0/deviceManagement/deviceConfigurations/{0}/assignments' -f $profileId)
                        $profileAssignments = Invoke-SguGraphPagedRequest -Uri $profileAssignmentsEndpoint
                        foreach ($assignment in $profileAssignments) {
                            $target = Get-SguValue -Object $assignment -Name 'target'
                            if ($null -eq $target) { continue }

                            $odataType = [string](Get-SguValue -Object $target -Name '@odata.type')
                            if ($odataType -notmatch 'groupAssignmentTarget') { continue }

                            $groupId = [string](Get-SguValue -Object $target -Name 'groupId')
                            if (-not [string]::IsNullOrWhiteSpace($groupId)) {
                                Add-Evidence -Entry $entry `
                                    -GroupId $groupId `
                                    -GroupDisplayName (Resolve-GroupDisplayName -GroupId $groupId) `
                                    -ObjectType 'DeviceConfigurationAssignment' `
                                    -ObjectId ([string](Get-SguValue -Object $assignment -Name 'id')) `
                                    -ObjectName $profileDisplayName `
                                    -AssignmentMode (if ($odataType -match 'exclusion') { 'Exclude' } else { 'Include' }) `
                                    -SourceType 'Graph' `
                                    -SourceLink $profileAssignmentsEndpoint
                                $count++
                            }
                        }
                    }
                    Add-Telemetry -Workload ($entry.UsageArea + ' (Config)') -Endpoint $configEndpoint -Start $configStart -ItemCount $count -Status 'Success' -ErrorText ''
                }
                catch {
                    Add-Telemetry -Workload ($entry.UsageArea + ' (Config)') -Endpoint 'deviceManagement/deviceConfigurations' -Start (Get-Date) -ItemCount 0 -Status 'Error' -ErrorText ([string]$_.Exception.Message)
                }
            }
            elseif ($entry.UsageArea -match 'Exchange Online') {
                $start = Get-Date
                $mailEndpoint = 'https://graph.microsoft.com/v1.0/groups?$filter=mailEnabled eq true and securityEnabled eq true&$select=id,displayName,mail'
                $mailGroups = Invoke-SguGraphPagedRequest -Uri $mailEndpoint
                $count = 0

                foreach ($mg in $mailGroups) {
                    $mgId = [string](Get-SguValue -Object $mg -Name 'id')
                    if ([string]::IsNullOrWhiteSpace($mgId)) { continue }

                    $mgDisplayName = [string](Get-SguValue -Object $mg -Name 'displayName')
                    $mgMail = [string](Get-SguValue -Object $mg -Name 'mail')
                    Add-Evidence -Entry $entry `
                        -GroupId $mgId `
                        -GroupDisplayName $mgDisplayName `
                        -ObjectType 'MailEnabledSecurityGroup' `
                        -ObjectId $mgId `
                        -ObjectName (if ([string]::IsNullOrWhiteSpace($mgMail)) { $mgDisplayName } else { $mgMail }) `
                        -AssignmentMode 'MailEnabled' `
                        -SourceType 'Graph' `
                        -SourceLink $mailEndpoint
                    $count++
                }

                Add-Telemetry -Workload $entry.UsageArea -Endpoint $mailEndpoint -Start $start -ItemCount $count -Status 'Success' -ErrorText ''
                $status = 'Queryable'
            }
            else {
                $status = 'PartiallyQueryable'
                $manualHint = switch -Regex ($entry.UsageArea) {
                    'Insider Risk' { 'Open Purview compliance portal > Insider Risk Management > Settings > Priority user groups to review group assignments.' }
                    'SharePoint' { 'Use SharePoint Admin Center > Active sites and review site permissions per site. PnP PowerShell (Get-PnPGroupPermissions) enables bulk review.' }
                    'Teams' { 'Use Teams Admin Center > Users > Manage users, or run Get-CsUserPolicyAssignment in Teams PowerShell to find group-based policy assignments.' }
                    'Defender' { 'Review Microsoft Defender XDR unified RBAC under Settings > Microsoft Defender XDR > Roles. For device groups, check Settings > Endpoints > Device groups.' }
                    default { 'No automated Graph collector available. Review the workload portal directly or consult documentation for manual validation steps.' }
                }
                Add-Telemetry -Workload $entry.UsageArea -Endpoint 'n/a' -Start (Get-Date) -ItemCount 0 -Status 'PartiallyQueryable' -ErrorText $manualHint
            }
        }
        catch {
            $status = 'Error'
            $errorText = [string]$_.Exception.Message
            Add-Telemetry -Workload $entry.UsageArea -Endpoint 'n/a' -Start (Get-Date) -ItemCount 0 -Status 'Error' -ErrorText $errorText
        }

        $findings = [int]($evidence.Count - $beforeCount)
        if ($findings -lt 0) {
            $findings = 0
        }

        $message = ''
        if (-not [string]::IsNullOrWhiteSpace($errorText)) {
            $message = $errorText
        }

        $coverage.Add([pscustomobject]@{
                WorkloadId = $entry.Id
                Workload   = $entry.UsageArea
                Capability = $entry.Capability
                Status     = $status
                Findings   = $findings
                Message    = $message
            })
        $resultColor = if ($status -eq 'Error') { 'Red' } elseif ($status -eq 'PartiallyQueryable') { 'Yellow' } elseif ($findings -gt 0) { 'Green' } else { 'DarkGray' }
        Write-Host (' [{0}] {1} finding(s)' -f $status, $findings) -ForegroundColor $resultColor
    }

    Write-Progress -Activity 'Collecting Evidence' -Completed

    $evidenceArray = $evidence.ToArray()
    $coverageArray = $coverage.ToArray()
    $telemetryArray = $telemetry.ToArray()
    $securityGroupArray = $securityGroups.ToArray()

    return [pscustomobject]@{
        Evidence       = $evidenceArray
        Coverage       = $coverageArray
        Telemetry      = $telemetryArray
        SecurityGroups = $securityGroupArray
    }
}
