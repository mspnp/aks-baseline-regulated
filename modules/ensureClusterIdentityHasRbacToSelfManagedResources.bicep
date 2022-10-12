targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('The AKS Control Plane Principal Id to be given with Network Contributor Role in different spoke subnets, so it can join VMSS and load balancers resources to them.')
@minLength(36)
@maxLength(36)
param miClusterControlPlanePrincipalId string

@description('The AKS Control Plane Principal Name to be used to create unique role assignments names.')
@minLength(3)
@maxLength(128)
param clusterControlPlaneIdentityName string

@description('The regional network spoke VNet Resource name that the cluster is being joined to, so it can be used to discover subnets during role assignments.')
@minLength(1)
param targetVirtualNetworkName string

/*** EXISTING SUBSCRIPTION RESOURCES ***/

resource networkContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '4d97b98b-1d4f-4787-a291-c67834d212e7'
  scope: subscription()
}

resource dnsZoneContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'b12aa53e-6015-4669-85d0-8515ebb3ae7f'
  scope: subscription()
}

/*** EXISTING SPOKE RESOURCES ***/

resource pdzCr 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
    name: 'privatelink.azurecr.io'
}

resource targetVirtualNetwork 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: targetVirtualNetworkName

  resource snetClusterSystemNodePools 'subnets' existing = {
    name: 'snet-cluster-systemnodepool'
  }

  resource snetClusterInScopeNodePools 'subnets' existing = {
    name: 'snet-cluster-inscopenodepools'
  }

  resource snetClusterOutofScopeNodePools 'subnets' existing = {
    name: 'snet-cluster-outofscopenodepools'
  }

  resource snetClusterIngressServices 'subnets' existing = {
    name: 'snet-cluster-ingressservices'
  }
}

/*** RESOURCES ***/

resource vnetMiClusterControlPlaneDnsZoneContributorRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: targetVirtualNetwork
  name: guid(targetVirtualNetwork.id, dnsZoneContributorRole.id, clusterControlPlaneIdentityName)
  properties: {
    roleDefinitionId: dnsZoneContributorRole.id
    description: 'Allows cluster identity to attach custom DNS zone with Private Link information to this virtual network.'
    principalId: miClusterControlPlanePrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource snetSystemNodePoolSubnetMiClusterControlPlaneNetworkContributorRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: targetVirtualNetwork::snetClusterSystemNodePools
  name: guid(targetVirtualNetwork::snetClusterSystemNodePools.id, networkContributorRole.id, clusterControlPlaneIdentityName)
  properties: {
    roleDefinitionId: networkContributorRole.id
    description: 'Allows cluster identity to join the nodepool vmss resources to this subnet.'
    principalId: miClusterControlPlanePrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource snetInScopeNodePoolSubnetsnetSystemNodePoolSubnetMiClusterControlPlaneNetworkContributorRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: targetVirtualNetwork::snetClusterInScopeNodePools
  name: guid(targetVirtualNetwork::snetClusterInScopeNodePools.id, networkContributorRole.id, clusterControlPlaneIdentityName)
  properties: {
    roleDefinitionId: networkContributorRole.id
    description: 'Allows cluster identity to join the nodepool vmss resources to this subnet.'
    principalId: miClusterControlPlanePrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource snetOutOfScopeNodePoolSubnetMiClusterControlPlaneNetworkContributorRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: targetVirtualNetwork::snetClusterOutofScopeNodePools
  name: guid(targetVirtualNetwork::snetClusterOutofScopeNodePools.id, networkContributorRole.id, clusterControlPlaneIdentityName)
  properties: {
    roleDefinitionId: networkContributorRole.id
    description: 'Allows cluster identity to join the nodepool vmss resources to this subnet.'
    principalId: miClusterControlPlanePrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource snetIngressServicesSubnetMiClusterControlPlaneNetworkContributorRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: targetVirtualNetwork::snetClusterIngressServices
  name: guid(targetVirtualNetwork::snetClusterIngressServices.id, networkContributorRole.id, clusterControlPlaneIdentityName)
  properties: {
    roleDefinitionId: networkContributorRole.id
    description: 'Allows cluster identity to join load balancers (ingress resources) to this subnet.'
    principalId: miClusterControlPlanePrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource pdzCrPrivatelinkAzmk8sIoMiClusterControlPlaneDnsZoneContributorRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: pdzCr
  name: guid(pdzCr.id, dnsZoneContributorRole.id, clusterControlPlaneIdentityName)
  properties: {
    roleDefinitionId: dnsZoneContributorRole.id
    description: 'Allows cluster identity to manage zone Entries for cluster\'s Private Link configuration.'
    principalId: miClusterControlPlanePrincipalId
    principalType: 'ServicePrincipal'
  }
}
