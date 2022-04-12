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

@description('Ensures that Microsoft Defender for Kuberentes Service, Container Service, and Key Vault are enabled. - Policy Assignment')
param enableDefenderPolicyDefinitionSetName string

/*** RESOURCES ***/

@description('Assignment of policy')
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' =  {
    name: guid(enableDefenderPolicyDefinitionSetName, subscription().id)
    identity: {
        type: 'SystemAssigned'
    }
    location: location
    properties: {
        displayName: reference(subscriptionResourceId('Microsoft.Authorization/policySetDefinitions', enableDefenderPolicyDefinitionSetName), '2020-09-01').displayName
        description: 'Ensures that Microsoft Defender for Kuberentes Service, Container Service, and Key Vault are enabled.'
        notScopes: []
        policyDefinitionId: subscriptionResourceId('Microsoft.Authorization/policySetDefinitions', enableDefenderPolicyDefinitionSetName)
        enforcementMode: enforcementMode
        metadata: {
            version: '1.0.0'
            category: 'Microsoft Defender for Cloud'
        }
    }
}
