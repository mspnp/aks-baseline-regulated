targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('allowedResources Policy Definition Id')
param allowedResourcesPolicyDefinitionId string

@description('The Network Watchers resource group')
param rgNetworkWatchers string

/*** RESOURCES ***/

@description('Allowed Resources Policy applied to the network watchers resource group to only allow select networking resources.')
module allowedResourcespolicyAssignment 'policyAssignmentDeploymentRG.bicep' = {
    name: 'NetworkWatchers-allowedResourcespolicyAssignment'
    scope: resourceGroup(rgNetworkWatchers)
    params: {
        name: guid(allowedResourcesPolicyDefinitionId, rgNetworkWatchers)
        displayName: trim(take('[${rgNetworkWatchers}] ${reference(allowedResourcesPolicyDefinitionId, '2020-09-01').displayName}', 125))
        policyAssignmentDescription: 'List of supported resources for our Network Watcher resource group'
        policyDefinitionId: allowedResourcesPolicyDefinitionId
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

