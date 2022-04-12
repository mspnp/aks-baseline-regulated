targetScope = 'resourceGroup'

/*** RESOURCES ***/

@description('\'No Public IPs on VMSS\' policy applied to the workload resource group. - Policy Assignment')
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' =  {
    name: guid(guid(subscription().id, 'NoPublicIPsForVMScaleSets'), resourceGroup().name)
    properties: {
        displayName: trim(take('[${resourceGroup().name}] ${reference(subscriptionResourceId('Microsoft.Authorization/policyDefinitions', guid(subscription().id, 'NoPublicIPsForVMScaleSets')), '2020-09-01').displayName}', 125))
        policyDefinitionId: subscriptionResourceId('Microsoft.Authorization/policyDefinitions', guid(subscription().id, 'NoPublicIPsForVMScaleSets'))
        parameters: {}
    }
}
