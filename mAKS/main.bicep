targetScope = 'subscription'

// params
param name string
param location string
param environment string

// AKS params
param adminGroupObjectIDs string[]
param kubernetesVersion string
param nodePools array
param networkProfile object
param privateDNSZoneId string

// param podCidr string
// param serviceCidr string
// param dnsServiceIP string
// param networkPlugin string

// VNET params
param vnetName string
param vnetRgName string
param snetPrivateEndpointName string
//param snetManagmentCrAgentsName string

// Log Analytics params
param workspaceId string

// Step-by-step params
param deployAzDiagnostics bool


// Variables
var resourceName = '${name}-${environment}'

// Resource group

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${resourceName}'
  location: location
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: vnetName
  scope: resourceGroup(vnetRgName)
}

// Modules

module umi './bicep-modules/umi.bicep' = {
  name: 'umiDeploy'
  scope: resourceGroup(rg.name)
  params: {
    name: resourceName
    location: location
  }
}

// START - This resource is to be replaced by central DNSZone - used for test of AKS private cluster
module dnsZone './bicep-modules/privatednszone.bicep' = {
  name: 'dnsZoneDeploy'
  scope: resourceGroup(rg.name)
  params: {
    name: resourceName
    privateDnsZoneName: 'privatelink.${location}.azmk8s.io'
    vnetId: vnet.id
  }
  dependsOn: [
    umi
  ]
}
// END 

module acr './bicep-modules/acr.bicep' = {
  name: 'acrDeploy'
  scope: resourceGroup(rg.name)
  params: {
    name: resourceName
    location: location
    workspaceId: deployAzDiagnostics ? workspaceId : ''
    //snetManagmentCrAgentsId: resourceId(subscription().subscriptionId, vnetRgName, 'Microsoft.Network/virtualNetworks/subnets', vnetName, snetManagmentCrAgentsName) // or vnet::snetManagmentCrAgentsName::id
    snetPrivateEndpointId: resourceId(subscription().subscriptionId, vnetRgName, 'Microsoft.Network/virtualNetworks/subnets', vnetName, snetPrivateEndpointName) // or vnet::snetPrivateEndpointName::id
    deployAzDiagnostics: deployAzDiagnostics
  }
  dependsOn: [
    umi
    rbac
  ]
}

module akv './bicep-modules/akv.bicep' = {
  name: 'akvDeploy'
  scope: resourceGroup(rg.name)
  params: {
    name: resourceName
    location: location
    workspaceId: deployAzDiagnostics ? workspaceId : ''
    snetPrivateEndpointId: resourceId(subscription().subscriptionId, vnetRgName, 'Microsoft.Network/virtualNetworks/subnets', vnetName, snetPrivateEndpointName) // or vnet::snetPrivateEndpointName::id
    deployAzDiagnostics: deployAzDiagnostics
  }
  dependsOn: [
    umi
    rbac
  ]
}

module aks './bicep-modules/aks.bicep' = {
  name: 'aksDeploy'
  scope: resourceGroup(rg.name)
  params: {
    name: resourceName
    location: location
    adminGroupObjectIDs: adminGroupObjectIDs
    kubernetesVersion: kubernetesVersion
    agentPoolProfiles: nodePools
    networkProfile: networkProfile
    privateDNSZoneId: dnsZone.outputs.privateDNSZoneId
    vnetName: vnetName
    vnetRgName: vnetRgName
    workspaceId: deployAzDiagnostics ? workspaceId : ''
    deployAzDiagnostics: deployAzDiagnostics
  }
  dependsOn: [
    umi
    rbac
  ]
}

// RBAC

module rbac './bicep-modules/rbac.bicep' = {
  name: 'setRbacDeploy'
  scope: resourceGroup(vnetRgName)
  params: {
    name: resourceName
    vnetName: vnetName
    umiRgName: rg.name
  }
  dependsOn: [
    umi
  ]
}
