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

    try {
        $groupsStart = Get-Date
        $groupsEndpoint = 'https://graph.microsoft.com/v1.0/groups?$select=id,displayName,securityEnabled,mailEnabled,groupTypes'
        $allGroups = Invoke-SguGraphPagedRequest -Uri $groupsEndpoint
        $securityGroupCount = 0

        foreach ($group in $allGroups) {
            $groupId = [string](Get-SguValue -Object $group -Name 'id')
            if ([string]::IsNullOrWhiteSpace($groupId)) { continue }

            $groupDisplayName = [string](Get-SguValue -Object $group -Name 'displayName')
            $groupDisplayNameById[$groupId] = $groupDisplayName

            $isSecurityEnabled = [bool](Get-SguValue -Object $group -Name 'securityEnabled')
            if (-not $isSecurityEnabled) { continue }

            $groupTypesRaw = @((Get-SguValue -Object $group -Name 'groupTypes'))
            $groupTypes = @($groupTypesRaw | ForEach-Object { [string]$_ })

            $securityGroups.Add([pscustomobject]@{
                    GroupId          = $groupId
                    GroupDisplayName = $groupDisplayName
                    MailEnabled      = [bool](Get-SguValue -Object $group -Name 'mailEnabled')
                    GroupTypes       = ($groupTypes -join ';')
                })
            $securityGroupCount++
        }

        Add-Telemetry -Workload 'Security Group Directory' -Endpoint $groupsEndpoint -Start $groupsStart -ItemCount $securityGroupCount -Status 'Success' -ErrorText ''
    }
    catch {
        Add-Telemetry -Workload 'Security Group Directory' -Endpoint 'https://graph.microsoft.com/v1.0/groups' -Start (Get-Date) -ItemCount 0 -Status 'Error' -ErrorText ([string]$_.Exception.Message)
    }

    foreach ($entry in $WorkloadMatrix) {
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
            continue
        }

        try {
            if ($entry.UsageArea -match 'Entra ID Roles') {
                $start = Get-Date
                $endpoint = 'https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments?$select=id,principalId,roleDefinitionId,directoryScopeId'
                $assignments = Invoke-SguGraphPagedRequest -Uri $endpoint
                $count = 0

                foreach ($assignment in $assignments) {
                    $principalId = [string](Get-SguValue -Object $assignment -Name 'principalId')
                    if ([string]::IsNullOrWhiteSpace($principalId)) { continue }

                    $principalEndpoint = ("https://graph.microsoft.com/v1.0/directoryObjects/{0}" -f $principalId)
                    try {
                        $principal = Invoke-MgGraphRequest -Method GET -Uri $principalEndpoint
                        if ([string](Get-SguValue -Object $principal -Name '@odata.type') -eq '#microsoft.graph.group') {
                            Add-Evidence -Entry $entry -GroupId $principalId -GroupDisplayName ([string](Get-SguValue -Object $principal -Name 'displayName')) -ObjectType 'RoleAssignment' -ObjectId ([string](Get-SguValue -Object $assignment -Name 'id')) -ObjectName ([string](Get-SguValue -Object $assignment -Name 'roleDefinitionId')) -AssignmentMode 'Include' -SourceType 'Graph' -SourceLink $endpoint
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
            }
            else {
                $status = 'PartiallyQueryable'
                Add-Telemetry -Workload $entry.UsageArea -Endpoint 'n/a' -Start (Get-Date) -ItemCount 0 -Status 'Skipped' -ErrorText 'Collector not implemented for this partially queryable workload yet.'
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
    }

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
