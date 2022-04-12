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

/*** RESOURCES ***/

@description('Ensures Microsoft Defender is enabled for select resources.')
resource psdEnableDefender 'Microsoft.Authorization/policySetDefinitions@2021-06-01' existing = {
    name: guid(subscription().id, 'EnableDefender')
}

@description('Assignment of policy')
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' =  {
    name: psdEnableDefender.id
    identity: {
        type: 'SystemAssigned'
    }
    location: location
    properties: {
        displayName: psdEnableDefender.properties.displayName
        description: 'Ensures that Microsoft Defender for Kuberentes Service, Container Service, and Key Vault are enabled.'
        notScopes: []
        policyDefinitionId: psdEnableDefender.id
        enforcementMode: enforcementMode
        metadata: {
            version: '1.0.0'
            category: 'Microsoft Defender for Cloud'
        }
    }
}

