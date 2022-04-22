targetScope = 'resourceGroup'


@description('Allowed resource types - Policy definition')
resource allowedResourceTypespolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
    name: 'a08ec900-254a-4555-9bf5-e42af04b5c5c'
    scope: subscription()
}

@description('Network Watcher should be enabled - Policy Definition')
resource NetworkWatcherShouldBeEnabledPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
    name: 'b6e2945c-0b7b-40f5-9233-7a5323b5cdc6'
    scope: subscription()
}


/*** RESOURCES ***/

@description('Allowed Resources Policy applied to the spokes RG to only allow select networking and observation resources.')
module allowedResourcespolicyAssignment 'resourceGroupPolicyAssignment.bicep' = {
    name: 'Spokes-allowedResourcespolicyAssignment'
    scope: resourceGroup()
    params: {
        builtIn: true
        policyDefinitionName: allowedResourceTypespolicyDefinition.name
        policyAssignmentDescription: 'List of supported resources for our enterprise spokes resource group'
        policyAssignmentParameters: {
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
module NetworkWatcherShouldBeEnabledPolicyAssignment 'resourceGroupPolicyAssignment.bicep' = {
    name: 'Spokes-NetworkWatcherShouldBeEnabledPolicyAssignment'
    scope: resourceGroup()
    params: {
        builtIn: true
        policyDefinitionName: NetworkWatcherShouldBeEnabledPolicyDefinition.name
        policyAssignmentDescription: 'Applying the \'Network Watcher Should be Enabled\' policy to the Spoke resource group.'
    }
}
