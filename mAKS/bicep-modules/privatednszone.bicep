param privateDnsZoneName string
param name string
param vnetId string 

var privateDnsContributorRoleDefId = 'b12aa53e-6015-4669-85d0-8515ebb3ae7f'

resource umi 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: 'umi-${name}'
}


resource privateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global'
}

resource setPrivateDnsZoneRbac 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: privateDNSZone
  name: guid(umi.id, privateDnsContributorRoleDefId, privateDNSZone.name)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', privateDnsContributorRoleDefId)
    principalId: umi.properties.principalId
    principalType: 'ServicePrincipal'
  }
}


resource privateDnslink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: '${privateDnsZoneName}/${privateDnsZoneName}-link-vnet-${name}'
  location: 'global'
  properties: {
    registrationEnabled: contains(privateDnsZoneName,name) ? true : false 
    virtualNetwork: {
      id: vnetId
    }
  }
  dependsOn: [
    privateDNSZone
  ]
}

output privateDNSZoneId string = privateDNSZone.id
output privateDNSZoneName string = privateDNSZone.name
