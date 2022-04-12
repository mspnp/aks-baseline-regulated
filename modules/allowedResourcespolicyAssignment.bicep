targetScope = 'resourceGroup'

/*** RESOURCES ***/

@description('Only support the a list of resources for our workload resource group - Policy assignment')
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' =  {
    name: guid('/providers/Microsoft.Authorization/policyDefinitions/a08ec900-254a-4555-9bf5-e42af04b5c5c', resourceGroup().name)
    properties: {
        displayName: trim(take('[${resourceGroup().name}] ${reference('/providers/Microsoft.Authorization/policyDefinitions/a08ec900-254a-4555-9bf5-e42af04b5c5c', '2020-09-01').displayName}', 125))
        description: 'List of supported resources for our workload resource group'
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/a08ec900-254a-4555-9bf5-e42af04b5c5c'
        parameters: {
            listOfResourceTypesAllowed: {
                value: [
                    'Microsoft.Compute/images'
                    'Microsoft.Compute/virtualMachineScaleSets'
                    'Microsoft.ContainerRegistry/registries'
                    'Microsoft.ContainerRegistry/registries/agentPools'
                    'Microsoft.ContainerRegistry/registries/replications'
                    'Microsoft.ContainerService/managedClusters'
                    'Microsoft.Insights/activityLogAlerts'
                    'Microsoft.Insights/metricAlerts'
                    'Microsoft.Insights/scheduledQueryRules'
                    'Microsoft.Insights/workbooks'
                    'Microsoft.KeyVault/vaults'
                    'Microsoft.ManagedIdentity/userAssignedIdentities'
                    'Microsoft.Network/applicationGateways'
                    'Microsoft.Network/networkInterfaces'
                    'Microsoft.Network/networkSecurityGroups'
                    'Microsoft.Network/networkSecurityGroups/securityRules'
                    'Microsoft.Network/privateDnsZones'
                    'Microsoft.Network/privateDnsZones/virtualNetworkLinks'
                    'Microsoft.Network/privateEndpoints'
                    'Microsoft.OperationalInsights/workspaces'
                    'Microsoft.OperationsManagement/solutions'
                    'Microsoft.VirtualMachineImages/imageTemplates'
                ]
            }
        }
    }
}
