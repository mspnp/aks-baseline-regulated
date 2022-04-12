targetScope = 'resourceGroup'

/*** RESOURCES ***/

@description('Allowed Resources Policy applied to the network watchers resource group to only allow select networking resources.')
module allowedResourcespolicyAssignment 'policyAssignmentDeploymentRG.bicep' = {
    name: 'NetworkWatchers-allowedResourcespolicyAssignment'
    scope: resourceGroup()
    params: {
        name: guid('/providers/Microsoft.Authorization/policyDefinitions/a08ec900-254a-4555-9bf5-e42af04b5c5c', resourceGroup().name)
        displayName: trim(take('[${resourceGroup().name}] ${reference('/providers/Microsoft.Authorization/policyDefinitions/a08ec900-254a-4555-9bf5-e42af04b5c5c', '2020-09-01').displayName}', 125))
        policyAssignmentDescription: 'List of supported resources for our Network Watcher resource group'
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/a08ec900-254a-4555-9bf5-e42af04b5c5c'
        enforcementMode: 'DoNotEnforce'        
        parameters: {
            listOfResourceTypesAllowed: {
                value: [
                    'Microsoft.Network/networkWatchers'
                    'Microsoft.Network/networkWatchers/flowLogs'
                ]
            }
        }
    }
}

