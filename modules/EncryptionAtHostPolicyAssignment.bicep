targetScope = 'resourceGroup'

/*** RESOURCES ***/

@description('\'Encryption at Host\' policy applied to the resource group - Policy Assignment.')
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' =  {
    name: guid('/providers/Microsoft.Authorization/policyDefinitions/41425d9f-d1a5-499a-9932-f8ed8453932c', resourceGroup().name)
    properties: {
        displayName: trim(take('[${resourceGroup().name}] ${reference('/providers/Microsoft.Authorization/policyDefinitions/41425d9f-d1a5-499a-9932-f8ed8453932c', '2020-09-01').displayName}', 125))
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/41425d9f-d1a5-499a-9932-f8ed8453932c'
        parameters: {}
    }
}
