targetScope = 'resourceGroup'

/*** RESOURCES ***/

@description('Disallow older AKS versions - Policy Assignment')
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' =  {
    name: guid('/providers/Microsoft.Authorization/policyDefinitions/fb893a29-21bb-418c-a157-e99480ec364c', resourceGroup().name)
    properties: {
        displayName: trim(take('[${resourceGroup().name}] ${reference('/providers/Microsoft.Authorization/policyDefinitions/fb893a29-21bb-418c-a157-e99480ec364c', '2020-09-01').displayName}', 125))
        description: 'Disallow older AKS versions.'
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/fb893a29-21bb-418c-a157-e99480ec364c'
        parameters: {}
    }
}
