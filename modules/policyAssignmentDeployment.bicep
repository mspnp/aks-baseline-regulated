targetScope = 'subscription'

/*** PARAMETERS ***/

@description('The definitionID of the policy to assign.')
param policyDefinitionId string

@description('The name of the policy assignment.')
param name string

@description('The policy assignment\'s display name.')
param displayName string

@description('The policy assignment\'s location.')
param location string

@description('Array of messages displayed when the policy is not compliant.')
param nonComplianceMessages array = []

@description('Object with parameters applied to the policy assignment. ')
param parameters object = {}

@description('Policy assignment\'s description.')
param policyAssignmentDescription string

@description('The policy\'s excluded scopes.')
param notScopes array = []

@description('Identity for the resource.')
param identity object = {}

@description('The policy assignment enforcement mode.')
param enforcementMode string = 'Default'

@description('The policy assignment metadata (it can be any object).')
param metadata object = {}

/*** RESOURCES ***/

@description('Assignment of policy')
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' =  {
    name: name
    identity: identity
    location: location
    properties: {
        displayName: displayName
        description: policyAssignmentDescription
        notScopes: notScopes
        policyDefinitionId: policyDefinitionId
        parameters: parameters
        nonComplianceMessages: nonComplianceMessages
        enforcementMode: enforcementMode
        metadata: metadata
    }
}
