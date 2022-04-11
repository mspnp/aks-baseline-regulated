targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('allowedResources Policy Definition Id')
param allowedResourcesPolicyDefinitionId string

@description('networkWatcherShouldBeEnabled Policy Definition Id')
param networkWatcherShouldBeEnabledPolicyDefinitionId string

@description('The hubs resource group')
param rgHubs string

/*** RESOURCES ***/

@description('Allowed Resources Policy applied to the hubs RG to only allow select networking and observation resources.')
module allowedResourcespolicyAssignment 'policyAssignmentDeploymentRG.bicep' = {
    name: 'Hubs-allowedResourcespolicyAssignment'
    scope: resourceGroup(rgHubs)
    params: {
        name: guid(allowedResourcesPolicyDefinitionId, rgHubs)
        displayName: trim(take('[${rgHubs}] ${reference(allowedResourcesPolicyDefinitionId, '2020-09-01').displayName}', 125))
        policyAssignmentDescription: 'List of supported resources for our enterprise hubs resource group'
        policyDefinitionId: allowedResourcesPolicyDefinitionId
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
    scope: resourceGroup(rgHubs)
    params: {
        name: guid(networkWatcherShouldBeEnabledPolicyDefinitionId, rgHubs)
        displayName: trim(take('[${rgHubs}] ${reference(networkWatcherShouldBeEnabledPolicyDefinitionId, '2020-09-01').displayName}', 125))
        policyAssignmentDescription: 'Applying the \'Network Watcher Should be Enabled\' policy to the Hub resource group.'
        policyDefinitionId: networkWatcherShouldBeEnabledPolicyDefinitionId
        parameters: {}
    }
}
