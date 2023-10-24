param name string
param location string
param subnetId string
param destinationId string
/*@allowed(
  [
  'privatelink.azurecr.io'
  'privatelink.vaultcore.azure.net'
  'privatelink.blob.core.windows.net'
  ]
)
param privateDnsZoneName string*/
@allowed(
  [
  'registry'
  'vault'
  'blob'
  ]
)
param groupId string
var privateEndpointName = 'pe-${name}'

/*resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: privateDnsZoneName
}*/

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2022-05-01' = {
  name: privateEndpointName
  location: location
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
        properties: {
          privateLinkServiceId: destinationId
          groupIds: [
            groupId
          ]
        }
      }
    ]
  }
}
/*
resource peEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = {
  name: '${privateEndpointName}/dnsgroup'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
  dependsOn: [
    privateEndpoint
  ]
}*/
