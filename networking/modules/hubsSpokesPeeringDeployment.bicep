targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('The hub\'s VNet resource Id')
@minLength(2)
param hubVNetResourceId string

@description('The spokes\'s VNet name')
@minLength(2)
param spokesVNetName string

@description('The remote VNet resourceId')
param remoteVirtualNetworkId string

/*** RESOURCEGROUP ***/

@description('Hub-to-spoke peering.')
resource hubsSpokesVirtualNetworkPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-05-01' = {
  name: '${last(split(hubVNetResourceId, '/'))}/hub-to-${spokesVNetName}'
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
