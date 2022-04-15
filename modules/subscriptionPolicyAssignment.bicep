targetScope = 'subscription'

/*** PARAMETERS ***/

@description('The policy assignment enforcement mode.')
param enforcementMode string = 'Default'

@description('Subsription deployment\'s main location (centralus if not specified)')
@allowed([
    'australiaeast'
    'canadacentral'
    'centralus'
    'eastus'
    'eastus2'
    'westus2'
    'francecentral'
    'germanywestcentral'
    'northeurope'
    'southafricanorth'
    'southcentralus'
    'uksouth'
    'westeurope'
    'japaneast'
    'southeastasia'
  ])
param location string = 'centralus'


@description('The name of the policy or policy set to assign.')
param policyDefinitionName string

@description('This object contains the type of policy assignment identity')
param policyAssignmentIdentity object = {}

@description('The desciption of the policy assignment')
param polcyAssignmentDescription string = ''

@description('Policy assignment metadata; this parameter can by any object')
param polcyAssignmentMetadata object = {}

@description('The policy\'s excluded scopes')
param notScopes array = []

/*** RESOURCES ***/

resource policyDefintion 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
    name: policyDefinitionName
    scope: subscription()
}

@description('Assignment of policy')
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' =  {
    name: guid(policyDefintion.name, subscription().id)
    identity: policyAssignmentIdentity
    location: location
    properties: {
        displayName: reference(subscriptionResourceId('Microsoft.Authorization/policySetDefinitions', policyDefintion.name), '2020-09-01').displayName
        description: polcyAssignmentDescription
        notScopes: notScopes
        policyDefinitionId: subscriptionResourceId('Microsoft.Authorization/policySetDefinitions', policyDefintion.name)
        enforcementMode: enforcementMode
        metadata: polcyAssignmentMetadata
    }
}
