targetScope = 'resourceGroup'

/*** RESOURCES ***/

@description('Microsoft Defender for Containers should be enabled in the cluster - Policy Assignment')
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' =  {
    name: guid(guid(subscription().id, 'DenyNonDefenderAks'), resourceGroup().name)
    properties: {
        displayName: trim(take('[${resourceGroup().name}] ${reference(subscriptionResourceId('Microsoft.Authorization/policyDefinitions', guid(subscription().id, 'DenyNonDefenderAks')), '2020-09-01').displayName}', 125))
        description: 'Microsoft Defender for Containers should be enabled in the cluster.'
        policyDefinitionId: subscriptionResourceId('Microsoft.Authorization/policyDefinitions', guid(subscription().id, 'DenyNonDefenderAks'))
        parameters: {}
    }
}
