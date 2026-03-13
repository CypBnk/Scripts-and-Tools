function Get-SguCatalog {
    [CmdletBinding()]
    param()

    $catalog = @(
        [pscustomobject]@{
            Id                 = 1
            Section            = 'Core Identity Assignments'
            UsageArea          = 'Entra ID Roles'
            Capability         = 'Queryable'
            QueryStrategy      = 'Graph role assignments + principal resolution'
            RequiredScopes     = @('RoleManagement.Read.Directory', 'Directory.Read.All')
            EndpointCandidates = @(
                'https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments?$select=id,principalId,roleDefinitionId,directoryScopeId',
                'https://graph.microsoft.com/v1.0/directoryObjects/{id}'
            )
            Links              = @(
                'https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/permissions-reference'
            )
        }
        [pscustomobject]@{
            Id                 = 2
            Section            = 'Core Identity Assignments'
            UsageArea          = 'Enterprise Applications'
            Capability         = 'Queryable'
            QueryStrategy      = 'Enumerate all service principals and collect group-targeted app role assignments via appRoleAssignedTo'
            RequiredScopes     = @('Application.Read.All', 'Group.Read.All')
            EndpointCandidates = @(
                'https://graph.microsoft.com/v1.0/servicePrincipals?$select=id,displayName',
                'https://graph.microsoft.com/v1.0/servicePrincipals/{id}/appRoleAssignedTo?$select=id,principalId,principalType,principalDisplayName'
            )
            Links              = @(
                'https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/what-is-application-management'
            )
        }
        [pscustomobject]@{
            Id                 = 3
            Section            = 'Core Identity Assignments'
            UsageArea          = 'Group-based Licensing'
            Capability         = 'Queryable'
            QueryStrategy      = 'Graph groups with assignedLicenses'
            RequiredScopes     = @('Group.Read.All')
            EndpointCandidates = @(
                'https://graph.microsoft.com/v1.0/groups?$select=id,displayName,assignedLicenses,securityEnabled'
            )
            Links              = @(
                'https://learn.microsoft.com/en-us/entra/fundamentals/concept-learn-about-groups'
            )
        }
        [pscustomobject]@{
            Id                 = 4
            Section            = 'Core Identity Assignments'
            UsageArea          = 'Conditional Access Policies'
            Capability         = 'Queryable'
            QueryStrategy      = 'Graph conditional access policies group targeting'
            RequiredScopes     = @('Policy.Read.All', 'Group.Read.All')
            EndpointCandidates = @(
                'https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies?$select=id,displayName,conditions,state'
            )
            Links              = @(
                'https://learn.microsoft.com/en-us/entra/identity/conditional-access/concept-conditional-access-users-groups'
            )
        }
        [pscustomobject]@{
            Id                 = 5
            Section            = 'Endpoint Management'
            UsageArea          = 'Intune Apps, Profiles, Compliance Policies'
            Capability         = 'Queryable'
            QueryStrategy      = 'Graph Intune app, device compliance policy, and device configuration profile assignments to groups'
            RequiredScopes     = @('DeviceManagementApps.Read.All', 'DeviceManagementConfiguration.Read.All', 'Group.Read.All')
            EndpointCandidates = @(
                'https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps?$select=id,displayName',
                'https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps/{id}/assignments',
                'https://graph.microsoft.com/v1.0/deviceManagement/deviceCompliancePolicies?$select=id,displayName',
                'https://graph.microsoft.com/v1.0/deviceManagement/deviceCompliancePolicies/{id}/assignments',
                'https://graph.microsoft.com/v1.0/deviceManagement/deviceConfigurations?$select=id,displayName',
                'https://graph.microsoft.com/v1.0/deviceManagement/deviceConfigurations/{id}/assignments'
            )
            Links              = @(
                'https://learn.microsoft.com/en-us/intune/intune-service/apps/apps-deploy',
                'https://learn.microsoft.com/en-us/intune/intune-service/fundamentals/quickstart-create-group',
                'https://learn.microsoft.com/en-us/intune/intune-service/protect/device-compliance-get-started'
            )
        }
        [pscustomobject]@{
            Id                 = 6
            Section            = 'Compliance & Security (Purview)'
            UsageArea          = 'Insider Risk Management Priority User Groups'
            Capability         = 'PartiallyQueryable'
            QueryStrategy      = 'Purview workload; use documented references for manual validation'
            RequiredScopes     = @()
            EndpointCandidates = @(
                'https://learn.microsoft.com/en-us/purview/insider-risk-management-settings-priority-user-groups'
            )
            Links              = @(
                'https://learn.microsoft.com/en-us/purview/insider-risk-management-settings-priority-user-groups',
                'https://learn.microsoft.com/en-us/purview/insider-risk-management-configure'
            )
        }
        [pscustomobject]@{
            Id                 = 7
            Section            = 'Communication Services'
            UsageArea          = 'Exchange Online (Mail-enabled Security Groups)'
            Capability         = 'Queryable'
            QueryStrategy      = 'Enumerate mail-enabled security groups via Graph; Exchange transport rule and policy usage requires manual EXO validation'
            RequiredScopes     = @('Group.Read.All')
            EndpointCandidates = @(
                'https://graph.microsoft.com/v1.0/groups?$filter=mailEnabled eq true and securityEnabled eq true&$select=id,displayName,mail'
            )
            Links              = @(
                'https://learn.microsoft.com/en-us/exchange/recipients-in-exchange-online/manage-mail-enabled-security-groups'
            )
            ManualValidationHint = 'Review Exchange Admin Center for transport rules and distribution group policies referencing these groups.'
        }
        [pscustomobject]@{
            Id                 = 8
            Section            = 'Collaboration Services'
            UsageArea          = 'SharePoint Online Site Permissions'
            Capability         = 'PartiallyQueryable'
            QueryStrategy      = 'Site-level group permissions require SharePoint APIs/admin endpoints'
            RequiredScopes     = @('Sites.Read.All', 'Group.Read.All')
            EndpointCandidates = @(
                'https://graph.microsoft.com/v1.0/sites/{site-id}/permissions'
            )
            Links              = @(
                'https://learn.microsoft.com/en-us/entra/fundamentals/concept-learn-about-groups'
            )
        }
        [pscustomobject]@{
            Id                 = 9
            Section            = 'Collaboration Services'
            UsageArea          = 'Teams Policies (Messaging, App Setup, etc.)'
            Capability         = 'PartiallyQueryable'
            QueryStrategy      = 'Policy assignment visibility primarily via Teams PowerShell/admin endpoints'
            RequiredScopes     = @('Group.Read.All')
            EndpointCandidates = @(
                'https://graph.microsoft.com/beta/policies/authorizationPolicy',
                'https://graph.microsoft.com/beta/teamwork/teamsAppSettings'
            )
            Links              = @(
                'https://learn.microsoft.com/en-us/microsoftteams/assign-policies-users-and-groups'
            )
            ManualValidationHint = 'Use Teams PowerShell (Get-CsUserPolicyAssignment) or Teams Admin Center to check group-based policy assignments.'
        }
        [pscustomobject]@{
            Id                 = 10
            Section            = 'Security Operations'
            UsageArea          = 'Microsoft Defender XDR (Roles, Device Groups)'
            Capability         = 'PartiallyQueryable'
            QueryStrategy      = 'Defender XDR role assignments and device group memberships are not fully accessible via standard Graph; manual validation required'
            RequiredScopes     = @()
            EndpointCandidates = @(
                'https://security.microsoft.com/settings/endpoints/roles'
            )
            Links              = @(
                'https://learn.microsoft.com/en-us/defender-xdr/manage-rbac',
                'https://learn.microsoft.com/en-us/defender-endpoint/machine-groups'
            )
            ManualValidationHint = 'In Microsoft Defender XDR, review unified RBAC roles under Settings > Microsoft Defender XDR > Roles. For MDE device groups, check Settings > Endpoints > Device groups in the Defender portal.'
        }
    )

    return , $catalog
}