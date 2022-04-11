targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('The definitionID of the policy to assign.')
param policyDefinitionId string

@description('The name of the policy assignment.')
param name string

@description('The policy assignment\'s display name.')
param displayName string

@description('Object with parameters applied to the policy assignment. ')
param parameters object

@description('Policy assignment\'s description')
param policyAssignmentDescription string = ''

@description('Provides the ability to test the outcome of a policy on existing resources without initiating the policy effect')
param enforcementMode string = 'Default'

/*** RESOURCES ***/

@description('Assignment of policy')
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' =  {
    name: name
    properties: {
        displayName: displayName
        description: policyAssignmentDescription
        enforcementMode: enforcementMode
        policyDefinitionId: policyDefinitionId
        parameters: parameters
    }
}
