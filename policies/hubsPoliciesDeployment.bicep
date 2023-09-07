targetScope = 'resourceGroup'

/*** EXISTING RESOURCES ***/

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

@description('Allowed Resources Policy applied to the hubs RG to only allow select networking and observation resources.')
module allowedResourcespolicyAssignment 'resourceGroupPolicyAssignment.bicep' = {
    name: 'Hubs-allowedResourcespolicyAssignment'
    scope: resourceGroup()
    params: {
        builtIn: true
        policyDefinitionName: allowedResourceTypespolicyDefinition.name
        policyAssignmentDescription: 'List of supported resources for our enterprise hubs resource group'
        policyAssignmentParameters: {
            listOfResourceTypesAllowed: {
                value: [
                    'Microsoft.Insights/diagnosticSettings'
                    'Microsoft.Insights/workbooks'
                    'Microsoft.Network/azureFirewalls'
                    'Microsoft.Network/bastionHosts'
                    'Microsoft.Network/ipGroups'
                    'Microsoft.Network/networkSecurityGroups'
                    'Microsoft.Network/networkSecurityGroups/securityRules'
                    'Microsoft.Network/publicIpAddresses'
                    'Microsoft.Network/virtualNetworkGateways'
                    'Microsoft.Network/virtualNetworks'
                    'Microsoft.Network/virtualNetworks/subnets'
                    'Microsoft.Network/virtualNetworks/virtualNetworkPeerings'
                    'Microsoft.OperationalInsights/workspaces'
                    'Microsoft.OperationsManagement/solutions'
                    'Microsoft.Storage/storageAccounts'
                ]
            }
        }
    }
}

@description('Applying the \'Network Watcher Should be Enabled\' policy to the Hub resource group.')
module NetworkWatcherShouldBeEnabledPolicyAssignment 'resourceGroupPolicyAssignment.bicep' = {
    name: 'Hubs-NetworkWatcherShouldBeEnabledPolicyAssignment'
    scope: resourceGroup()
    params: {
        builtIn: true
        policyDefinitionName: NetworkWatcherShouldBeEnabledPolicyDefinition.name
        policyAssignmentDescription: 'Applying the \'Network Watcher Should be Enabled\' policy to the Hub resource group.'
    }
}
