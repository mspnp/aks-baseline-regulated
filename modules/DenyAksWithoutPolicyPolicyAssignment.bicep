targetScope = 'resourceGroup'

/*** RESOURCES ***/

@description('Only support AKS clusters with Azure Policy enabled, deny any other. - Policy Assignment')
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' =  {
    name: guid('/providers/Microsoft.Authorization/policyDefinitions/0a15ec92-a229-4763-bb14-0ea34a568f8d', resourceGroup().name)
    properties: {
        displayName: trim(take('[${resourceGroup().name}] ${reference('/providers/Microsoft.Authorization/policyDefinitions/0a15ec92-a229-4763-bb14-0ea34a568f8d', '2020-09-01').displayName}', 125))
        description: 'Only support AKS clusters with Azure Policy enabled, deny any other.'
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/0a15ec92-a229-4763-bb14-0ea34a568f8d'
        parameters: {}
    }
}
