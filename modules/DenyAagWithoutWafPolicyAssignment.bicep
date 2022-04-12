targetScope = 'resourceGroup'

/*** RESOURCES ***/

@description('Only allow Azure Application Gateway SKU with WAF support. - Policy assignment')
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' =  {
    name: guid(guid(subscription().id, 'DenyAagWithoutWaf'), resourceGroup().name)
    properties: {
        displayName: trim(take('[${resourceGroup().name}] ${reference(subscriptionResourceId('Microsoft.Authorization/policyDefinitions', guid(subscription().id, 'DenyAagWithoutWaf')), '2020-09-01').displayName}', 125))
        description: 'Only allow Azure Application Gateway SKU with WAF support.'
        policyDefinitionId: subscriptionResourceId('Microsoft.Authorization/policyDefinitions', guid(subscription().id, 'DenyAagWithoutWaf'))
        parameters: {}
    }
}
