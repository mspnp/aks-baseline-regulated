targetScope = 'subscription'

/*** PARAMETERS ***/

@description('The definitionID of the policy to assign.')
param policyDefinitionId string

@description('The name of the policy assignment.')
param name string

@description('The policy assignment\'s display name.')
param displayName string

@description('Array of messages displayed when the policy is not compliant.')
param nonComplianceMessages array

@description('Object with parameters applied to the policy assignment. ')
param parameters object

@description('Policy assignment\'s description')
param policyAssignmentDescription string

/*** RESOURCES ***/

@description('Assignment of policy')
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' =  {
    name: name
    properties: {
        displayName: displayName
        description: policyAssignmentDescription
        notScopes: []
        policyDefinitionId: policyDefinitionId
        parameters: parameters
        nonComplianceMessages: nonComplianceMessages
    }
}
