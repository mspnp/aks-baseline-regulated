targetScope = 'resourceGroup'

/*** EXISTING RESOURCES ***/

@description('Allowed resource types - Policy definition')
resource allowedResourceTypespolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
    name: 'a08ec900-254a-4555-9bf5-e42af04b5c5c'
    scope: subscription()
}

/*** RESOURCES ***/

@description('Allowed Resources Policy applied to the network watchers resource group to only allow select networking resources.')
module allowedResourcespolicyAssignment 'resourceGroupPolicyAssignment.bicep' = {
    name: 'NetworkWatchers-allowedResourcespolicyAssignment'
    scope: resourceGroup()
    params: {
        builtIn: true
        policyDefinitionName: allowedResourceTypespolicyDefinition.name
        policyAssignmentDescription: 'List of supported resources for our Network Watcher resource group'
        policyAssignmentEnforcementMode: 'DoNotEnforce' // Since this RG may be under existing policy control in your subscription, adding this policy as audit-only.
        policyAssignmentParameters: {
            listOfResourceTypesAllowed: {
                value: [
                    'Microsoft.Network/networkWatchers'
                    'Microsoft.Network/networkWatchers/flowLogs'
                ]
            }
        }
    }
}

