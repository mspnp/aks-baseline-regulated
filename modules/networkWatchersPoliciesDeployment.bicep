targetScope = 'resourceGroup'

/*** RESOURCES ***/

@description('Allowed Resources Policy applied to the network watchers resource group to only allow select networking resources.')
module allowedResourcespolicyAssignment 'resourceGroupPolicyAssignment.bicep' = {
    name: 'NetworkWatchers-allowedResourcespolicyAssignment'
    scope: resourceGroup()
    params: {
        builtIn: true
        policyDefinitionName: 'a08ec900-254a-4555-9bf5-e42af04b5c5c'
        policyAssignmentDescription: 'List of supported resources for our Network Watcher resource group'
        policyAssignmentEnforcementMode: 'DoNotEnforce'
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

