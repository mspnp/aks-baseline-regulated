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
param deployAzDiagnostics bool


// Variables
var resourceName = '${name}-${environment}'

// Existing resources
/*resource la 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = if (deployAzDiagnostics) {
  name: workspaceName
  scope: resourceGroup(workspaceSubscriptionId, workspaceGroupName)
}*/

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

module acr './bicep-modules/acr.bicep' = {
  name: 'acrDeploy'
  scope: resourceGroup(rg.name)
  params: {
    name: resourceName
    location: location
    workspaceId: ''//deployAzDiagnostics ? la.id : '' 
    snetManagmentCrAgentsId: resourceId(subscription().subscriptionId, vnetRgName, 'Microsoft.Network/virtualNetworks/subnets', vnetName, snetManagmentCrAgentsName) // or vnet::snetManagmentCrAgentsName::id
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
    workspaceId: ''// deployAzDiagnostics ? la.id : ''
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
    // podCidr: podCidr
    // serviceCidr: serviceCidr
    // dnsServiceIP: dnsServiceIP
    // networkPlugin: networkPlugin
    networkProfile: networkProfile
    privateDNSZoneId: privateDNSZoneId
    vnetName: vnetName
    vnetRgName: vnetRgName
    workspaceId: ''//deployAzDiagnostics ? la.id : ''
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