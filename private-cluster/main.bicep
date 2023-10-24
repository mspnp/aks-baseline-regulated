targetScope = 'subscription'

// params
param name string
param location string
param environment string

// AKS params
param admingroupobjectid string
param kubernetesVersion string
param nodePools array
param podCidr string
param serviceCidr string
param dnsServiceIP string
param networkPlugin string

// VNET params
param vnetName string
param vnetRgName string

// Log Analytics params
param workspaceName string
param workspaceGroupName string
param workspaceSubscriptionId string

// Step-by-step params
param deployAzDiagnostics bool

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
module rg './bicep-modules/rg.bicep' = {
  name: 'rgDeploy'
  params: {
    location: location
    name: resourceName
  }
}

module umi './bicep-modules/umi.bicep' = {
  name: 'umiDeploy'
  scope: resourceGroup(rg.name)
  params: {
    name: resourceName
    location: location
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

/*module la './bicep-modules/loganalytics.bicep' = if(deployAzDiagnostics) {
  name: 'laDeploy'
  params: {
    name: resourceName
    location: location
  }
}*/

module acr './bicep-modules/acr.bicep' = {
  name: 'acrDeploy'
  scope: resourceGroup(rg.name)
  params: {
    name: resourceName
    location: location
    workspaceId: la.id
    snetManagmentCrAgentsId:
    snetPrivateEndpointId:
  }

}

module akv './bicep-modules/akv.bicep' = {
  name: 'akvDeploy'
  scope: resourceGroup(rg.name)
  params: {
    name: resourceName
    location: location
    workspaceId: la.id
    snetPrivateEndpointId:
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
    nodePools: nodePools
    podCidr: podCidr
    serviceCidr: serviceCidr
    dnsServiceIP: dnsServiceIP
    networkPlugin: networkPlugin
    // privateDnsZoneId: 
    workspaceId: la.id
  }
}
