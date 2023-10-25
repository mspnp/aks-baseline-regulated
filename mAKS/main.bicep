targetScope = 'subscription'

// params
param name string
param location string
param environment string

// AKS params
param admingroupobjectid string
//param availabilityZoneCount int
param kubernetesVersion string
param nodePools array
param podCidr string
param serviceCidr string
param dnsServiceIP string
param networkPlugin string

// VNET params
param vnetName string
param vnetRgName string
param snetPrivateEndpointName string
param snetManagmentCrAgentsName string

// Log Analytics params
param workspaceName string
param workspaceGroupName string
param workspaceSubscriptionId string

// Step-by-step params
//param deployAzDiagnostics bool

// Variables
var resourceName = '${name}-${environment}'

// Existing resources
resource la 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: workspaceName
  scope: resourceGroup(workspaceSubscriptionId, workspaceGroupName)
}

resource vnet 'Microsoft.ScVmm/virtualNetworks@2023-04-01-preview' existing = {
  name: vnetName
  scope: resourceGroup(vnetRgName)
}

// Modules
/*module rg './bicep-modules/rg.bicep' = {
  name: 'rgDeploy'
  params: {
    name: resourceName
    location: location
  }
}*/
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${resourceName}'
  location: location
//  managedBy: managedBy
}


module umi './bicep-modules/umi.bicep' = {
  name: 'umiDeploy'
  scope: resourceGroup(rg.name)
  params: {
    name: resourceName
    location: location
  }
}

module acr './bicep-modules/acr.bicep' = {
  name: 'acrDeploy'
  scope: resourceGroup(rg.name)
  params: {
    name: resourceName
    location: location
    workspaceId: la.id
    snetManagmentCrAgentsId: resourceId(vnetRgName, 'Microsoft.Network/virtualNetworks/subnets', vnetName, snetManagmentCrAgentsName) // or vnet::snetManagmentCrAgentsName::id
    snetPrivateEndpointId: resourceId(vnetRgName, 'Microsoft.Network/virtualNetworks/subnets', vnetName, snetPrivateEndpointName) // or vnet::snetPrivateEndpointName::id
  }
}

module akv './bicep-modules/akv.bicep' = {
  name: 'akvDeploy'
  scope: resourceGroup(rg.name)
  params: {
    name: resourceName
    location: location
    workspaceId: la.id
    snetPrivateEndpointId: resourceId(vnetRgName, 'Microsoft.Network/virtualNetworks/subnets', vnetName, snetPrivateEndpointName) // or vnet::snetPrivateEndpointName::id
  }
}

module aks './bicep-modules/aks.bicep' = {
  name: 'aksDeploy'
  scope: resourceGroup(rg.name)
  params: {
    name: resourceName
    location: location
    adminGroupObjectIDs: admingroupobjectid
    kubernetesVersion: kubernetesVersion
    agentPoolProfiles: nodePools
    podCidr: podCidr
    serviceCidr: serviceCidr
    dnsServiceIP: dnsServiceIP
    networkPlugin: networkPlugin
    vnetName: vnetName
    vnetRgName: vnetRgName
    workspaceId: la.id
  }
}

// Set network contrib for umi
module setRbac './bicep-modules/rbac.bicep' = {
  name: 'setRbacDeploy'
  scope: resourceGroup(vnetRgName)
  params: {
    name: resourceName
    vnetName: vnetName
  }
  dependsOn: [
    umi
  ]
}
