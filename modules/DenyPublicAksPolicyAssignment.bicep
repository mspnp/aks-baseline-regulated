targetScope = 'resourceGroup'

@description('Only support private AKS clusters, deny any other. - Policy Assignment')
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' =  {
    name: guid(guid(subscription().id, 'DenyPublicAks'), resourceGroup().name)
    properties: {
        displayName: trim(take('[${resourceGroup().name}] ${reference(subscriptionResourceId('Microsoft.Authorization/policyDefinitions', guid(subscription().id, 'DenyPublicAks')), '2020-09-01').displayName}', 125))
        description: 'Only support private AKS clusters, deny any other.'
        policyDefinitionId: subscriptionResourceId('Microsoft.Authorization/policyDefinitions', guid(subscription().id, 'DenyPublicAks'))
        parameters: {}
    }
}
