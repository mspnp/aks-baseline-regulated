targetScope = 'resourceGroup'

@description('\'Customer-Managed Disk Encryption\' applied to resource group - Policy Assignment.')
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' =  {
    name: guid('/providers/Microsoft.Authorization/policyDefinitions/7d7be79c-23ba-4033-84dd-45e2a5ccdd67', resourceGroup().name)
    properties: {
        displayName: trim(take('[${resourceGroup().name}] ${reference('/providers/Microsoft.Authorization/policyDefinitions/7d7be79c-23ba-4033-84dd-45e2a5ccdd67', '2020-09-01').displayName}', 125))
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/7d7be79c-23ba-4033-84dd-45e2a5ccdd67'
        parameters: {}
    }
}
