targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('allowedResources Policy Definition Id')
param allowedResourcesPolicyDefinitionId string

@description('networkWatcherShouldBeEnabled Policy Definition Id')
param networkWatcherShouldBeEnabledPolicyDefinitionId string

@description('The spokes resource group')
param rgSpokes string

/*** RESOURCES ***/

@description('Allowed Resources Policy applied to the spokes RG to only allow select networking and observation resources.')
module allowedResourcespolicyAssignment 'policyAssignmentDeploymentRG.bicep' = {
    name: 'Spokes-allowedResourcespolicyAssignment'
    scope: resourceGroup(rgSpokes)
    params: {
        name: guid(allowedResourcesPolicyDefinitionId, rgSpokes)
        displayName: trim(take('[${rgSpokes}] ${reference(allowedResourcesPolicyDefinitionId, '2020-09-01').displayName}', 125))
        policyAssignmentDescription: 'List of supported resources for our enterprise spokes resource group'
        policyDefinitionId: allowedResourcesPolicyDefinitionId
        parameters: {
            listOfResourceTypesAllowed: {
                value: [
                    'Microsoft.Network/networkSecurityGroups'
                    'Microsoft.Network/privateDnsZones'
                    'Microsoft.Network/privateDnsZones/virtualNetworkLinks'
                    'Microsoft.Network/publicIpAddresses'
                    'Microsoft.Network/routeTables'
                    'Microsoft.Network/virtualNetworks'
                    'Microsoft.Network/virtualNetworks/subnets'
                    'Microsoft.Network/virtualNetworks/virtualNetworkPeerings'
                ]
            }
        }
    }
}

@description('Applying the \'Network Watcher Should be Enabled\' policy to the Hub resource group.')
module NetworkWatcherShouldBeEnabledPolicyAssignment 'policyAssignmentDeploymentRG.bicep' = {
    name: 'Spokes-NetworkWatcherShouldBeEnabledPolicyAssignment'
    scope: resourceGroup(rgSpokes)
    params: {
        name: guid(networkWatcherShouldBeEnabledPolicyDefinitionId, rgSpokes)
        displayName: trim(take('[${rgSpokes}] ${reference(networkWatcherShouldBeEnabledPolicyDefinitionId, '2020-09-01').displayName}', 125))
        policyAssignmentDescription: 'Applying the \'Network Watcher Should be Enabled\' policy to the Spoke resource group.'
        policyDefinitionId: networkWatcherShouldBeEnabledPolicyDefinitionId
        parameters: {}
    }
}
