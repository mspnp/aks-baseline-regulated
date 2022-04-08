targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('The name of the spokes resource group')
@minLength(1)
param spokesResourceGroupName string

@description('The name of the hub\'s vNet')
@minLength(2)
param hubNetworkName string

@description('The name of the vnet used for jumpbox image builds')
@minLength(2)
param imageBuilderVNetName string

/*** RESOURCEGROUP ***/

resource spokesResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  scope: subscription()
  name: spokesResourceGroupName
}

@description('This vnet is used exclusively for jumpbox image builds.')
resource imageBuilderVNet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  scope: spokesResourceGroup
  name: imageBuilderVNetName
}

resource hubsSpokesVirtualNetworkPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-05-01' = {
  name: '${hubNetworkName}/hub-to-${imageBuilderVNetName}'
  properties: {
    remoteVirtualNetwork: {
      id: imageBuilderVNet.id
  }
  allowForwardedTraffic: false
  allowGatewayTransit: false
  allowVirtualNetworkAccess: true
  useRemoteGateways: false
  }
}
