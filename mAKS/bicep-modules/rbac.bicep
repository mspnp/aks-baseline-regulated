param name string
param vnetName string
param umi object

var networkContributorRoleDefId = '4d97b98b-1d4f-4787-a291-c67834d212e7'


resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: vnetName
}

resource setVnetRbac 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: 'rbacDeploy'//guid(umi.outputs.name, networkContributorRoleDefId, name)
  scope: vnet
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', networkContributorRoleDefId)
    principalId: umi.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}
