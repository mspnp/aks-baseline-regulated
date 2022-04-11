targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('The hub\'s VNet name')
@minLength(2)
param hubNetworkName string

@description('The spokes\'s VNet name')
@minLength(2)
param spokesVNetName string

@description('The remote VNet resourceId')
param remoteVirtualNetworkId string

/*** RESOURCEGROUP ***/

resource hubsSpokesVirtualNetworkPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-05-01' = {
  name: '${hubNetworkName}/hub-to-${spokesVNetName}'
  properties: {
    remoteVirtualNetwork: {
      id: remoteVirtualNetworkId
  }
  allowForwardedTraffic: false
  allowGatewayTransit: false
  allowVirtualNetworkAccess: true
  useRemoteGateways: false
  }
}
