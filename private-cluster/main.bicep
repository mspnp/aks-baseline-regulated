// params
param name string
param env string
param location string = resourceGroup().location
param admingroupobjectid string
param vnetRgName string
param vnetName string
param kubernetesVersion string = '1.26'
param aksNodepools array

//param env string


// Step-by-step params
param deployAzDiagnostics bool

// Variables
var resourceName = '${name}-${env}'

// Modules
module umi './bicep-modules/umi.bicep' = {
  name: 'umiDeploy'
  params: {
    name: resourceName
    location: location
  }
}

// Set network contrib for umi
module setRbac './bicep-modules/rbac.bicep' = {
  name: 'setRbacDeploy'
  scope:resourceGroup(vnetRgName)
  params: {
    name: resourceName
    vnetName: vnetName
    rgName: resourceGroup().name
  }
  dependsOn: [
    umi
  ]
}

module la './bicep-modules/loganalytics.bicep' = if(deployAzDiagnostics) {
  name: 'laDeploy'
  params: {
    name: resourceName
    location: location
  }
}

module acr './bicep-modules/acr.bicep' = {
  name: 'acrDeploy'
  dependsOn: [
    la
  ]
  params: {
    name: resourceName
    location: location
  }
}

module akv './bicep-modules/akv.bicep' = {
  name: 'akvDeploy'
  dependsOn: [
    la
  ]
  params: {
    name: resourceName
    location: location
  }
}

module aks './bicep-modules/aks.bicep' = {
  name: 'aksDeploy'
  dependsOn: [
    la
  ]
  params: {
    name: resourceName
    location: location
    nodePools: aksNodepools
    adminGroupObjectIDs: admingroupobjectid
    dnsServiceIP: 
    kubernetesVersion: kubernetesVersion
    networkPlugin: 
    nodeResourceGroup: 
    podCidr: 
    privateDnsZoneId: 
    serviceCidr: 
  }
}
