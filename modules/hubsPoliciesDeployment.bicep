targetScope = 'resourceGroup'

/*** RESOURCES ***/

@description('Allowed Resources Policy applied to the hubs RG to only allow select networking and observation resources.')
module allowedResourcespolicyAssignment 'policyAssignmentDeploymentRG.bicep' = {
    name: 'Hubs-allowedResourcespolicyAssignment'
    scope: resourceGroup()
    params: {
        name: guid('/providers/Microsoft.Authorization/policyDefinitions/a08ec900-254a-4555-9bf5-e42af04b5c5c', resourceGroup().name)
        displayName: trim(take('[${resourceGroup().name}] ${reference('/providers/Microsoft.Authorization/policyDefinitions/a08ec900-254a-4555-9bf5-e42af04b5c5c', '2020-09-01').displayName}', 125))
        policyAssignmentDescription: 'List of supported resources for our enterprise hubs resource group'
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/a08ec900-254a-4555-9bf5-e42af04b5c5c'
        parameters: {
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
module NetworkWatcherShouldBeEnabledPolicyAssignment 'policyAssignmentDeploymentRG.bicep' = {
    name: 'Hubs-NetworkWatcherShouldBeEnabledPolicyAssignment'
    scope: resourceGroup()
    params: {
        name: guid('/providers/Microsoft.Authorization/policyDefinitions/b6e2945c-0b7b-40f5-9233-7a5323b5cdc6', resourceGroup().name)
        displayName: trim(take('[${resourceGroup().name}] ${reference('/providers/Microsoft.Authorization/policyDefinitions/b6e2945c-0b7b-40f5-9233-7a5323b5cdc6', '2020-09-01').displayName}', 125))
        policyAssignmentDescription: 'Applying the \'Network Watcher Should be Enabled\' policy to the Hub resource group.'
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/b6e2945c-0b7b-40f5-9233-7a5323b5cdc6'
        parameters: {}
    }
}
