targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('Determines whether the policy being assigned is built in or not.')
param builtIn bool = true

@description('The name of the policy to assign.')
param policyDefinitionName string

@description('The description of the policy assignment.')
param policyAssignmentDescription string = ''

@description('The desciption of the policy assignment')
param policyAssignmentParameters object = {}

@description('This property provides the ability to test the outcome of a policy on existing resources without initiating the policy effect or triggering entries in the Azure Activity log')
param policyAssignmentEnforcementMode string = 'Default'

resource policyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
    name: policyDefinitionName
    scope: subscription()
}

/*** RESOURCES ***/

@description('Assigns a Policy at Resource Group level')
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' =  {
    name: builtIn ? guid('/providers/Microsoft.Authorization/policyDefinitions/${policyDefintion.name}', resourceGroup().name) : guid(policyDefintion.name, resourceGroup().name)
    scope: resourceGroup()
    properties: {
        displayName: builtIn ? trim(take('[${resourceGroup().name}] ${reference('/providers/Microsoft.Authorization/policyDefinitions/${policyDefintion.name}', '2020-09-01').displayName}', 125)) : trim(take('[${resourceGroup().name}] ${reference(subscriptionResourceId('Microsoft.Authorization/policyDefinitions', policyDefintion.name), '2020-09-01').displayName}', 125))
        description: policyAssignmentDescription
        policyDefinitionId: builtIn ? '/providers/Microsoft.Authorization/policyDefinitions/${policyDefintion.name}' : subscriptionResourceId('Microsoft.Authorization/policyDefinitions', policyDefintion.name)
        parameters: policyAssignmentParameters
        enforcementMode: policyAssignmentEnforcementMode
    }
}

