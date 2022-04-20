targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('Indicates whether the policy being assigned is built in or not.')
param builtIn bool = true

@description('The name of the policy to assign.')
@minLength(36)
@maxLength(36)
param policyDefinitionName string

@description('The description of the policy assignment.')
@minLength(1)
param policyAssignmentDescription string

@description('The he policy assignment\'s parameters')
param policyAssignmentParameters object = {}

@description('This property provides the ability to test the outcome of a policy on existing resources without initiating the policy effect or triggering entries in the Azure Activity log')
@allowed([
    'Default'
    'DoNotEnforce'
])
param policyAssignmentEnforcementMode string = 'Default'

/*** EXISTING RESOURCES ***/

resource customPolicyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
    name: policyDefinitionName
    scope: subscription()
}

/*** VARIABLES ***/

var builtInPolicyDefinitionId = '/providers/Microsoft.Authorization/policyDefinitions/${policyDefinitionName}'

/*** RESOURCES ***/

@description('Assigns a Policy at Resource Group level')
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' =  {
    name: guid( builtIn ? builtInPolicyDefinitionId : customPolicyDefinition.id, resourceGroup().name)
    scope: resourceGroup()
    properties: {
        displayName: trim(take('[${resourceGroup().name}] ${ builtIn ? reference(builtInPolicyDefinitionId, '2021-06-01').displayName : customPolicyDefinition.properties.displayName }', 125))
        description: policyAssignmentDescription
        policyDefinitionId: builtIn ? builtInPolicyDefinitionId : customPolicyDefinition.id
        parameters: policyAssignmentParameters
        enforcementMode: policyAssignmentEnforcementMode
    }
}
