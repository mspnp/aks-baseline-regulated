targetScope = 'subscription'

/*** PARAMETERS ***/

@description('The policy assignment enforcement mode.')
@allowed([
    'Default'
    'DoNotEnforce'
])
param enforcementMode string = 'Default'

@description('Subsription deployment\'s main location.')
@minLength(4)
param location string

@description('The name of the policy set to assign.')
@minLength(36)
@maxLength(36)
param policyDefinitionSetName string

@description('The desciption of the policy assignment.')
@minLength(1)
param policyAssignmentDescription string

@description('Policy assignment metadata; this parameter can by any object.')
param polcyAssignmentMetadata object = {}

/*** VARIABLES ***/

var builtIntPolicyDefinitionSetId = subscriptionResourceId('Microsoft.Authorization/policySetDefinitions', policyDefinitionSetName)

/*** RESOURCES ***/

@description('Assignment of policy')
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' =  {
    name: guid(builtIntPolicyDefinitionSetId)
    identity: {
        type: 'SystemAssigned'
    }
    location: location
    scope: subscription()
    properties: {
        displayName: reference(builtIntPolicyDefinitionSetId, '2021-06-01').displayName
        description: policyAssignmentDescription
        notScopes: []
        policyDefinitionId: builtIntPolicyDefinitionSetId
        enforcementMode: enforcementMode
        metadata: polcyAssignmentMetadata
    }
}
