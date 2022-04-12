targetScope = 'resourceGroup'

/*** RESOURCES ***/

@description('Only allow AKS with RBAC support enabled. - Policy Assignment')
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' =  {
    name: guid('/providers/Microsoft.Authorization/policyDefinitions/ac4a19c2-fa67-49b4-8ae5-0b2e78c49457', resourceGroup().name)
    properties: {
        displayName: trim(take('[${resourceGroup().name}] ${reference('/providers/Microsoft.Authorization/policyDefinitions/ac4a19c2-fa67-49b4-8ae5-0b2e78c49457', '2020-09-01').displayName}', 125))
        description: 'Only allow AKS with RBAC support enabled.'
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/ac4a19c2-fa67-49b4-8ae5-0b2e78c49457'
        parameters: {}
    }
}
