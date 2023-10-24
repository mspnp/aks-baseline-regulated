param name string
param vnetName string


var networkContributorRoleDefId = '4d97b98b-1d4f-4787-a291-c67834d212e7'

// Existing resources
resource umi 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: 'umi-${name}'
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: vnetName
}

resource setVnetRbac 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(umi.id, networkContributorRoleDefId, name)
  scope: vnet
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', networkContributorRoleDefId)
    principalId: umi.properties.principalId
    principalType: 'ServicePrincipal'
  }
}
