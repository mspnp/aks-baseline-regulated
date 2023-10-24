// Deployment in two steps
//    1. Deploy umi and grant private dns zone contrib to umi
//    2. Deploy aks

// Errors not shown good when using modules
// az deployment group create -g rg-[resourcename]-dev-[index] -n mainDeploy -f .\main-dev.bicep
// az deployment group create -g rg-ninja-dev-07 -n mainDeploy -f .\main-dev.bicep



param location string = resourceGroup().location

var resourcename = '[SET RESOURCENAME]' 
var admingroupobjectid = '[SET ADMIN GROUP OBJECT ID]'
var loganalyticsworkspaceId = '[SET LOGANALYTICS WORKSPACE ID]'
var privateDnsZoneId = '[SET PRIVATE DNS ZONE ID FOR AKS]'
var vnetAkSubnetId = '[SET AKS SUBNET ID]'
var kubernetesVersion = '[SET KUBERNETES VERSION]' //1.26
var vnetName = '[SET VNET NAME]'
var env = '[SET ENV+INDEX]'



var vnetRgName = 'rg-network' 


module deployEnv '../lib/main.bicep' = {
  name: 'deployEnv'
  params: {
    resourcename: resourcename 
    admingroupobjectid: admingroupobjectid
    loganalyticsworkspaceId:loganalyticsworkspaceId
    privateDnsZoneId: privateDnsZoneId
    vnetAkSubnetId: vnetAkSubnetId
    vnetRgName: vnetRgName
    deployAks: false
    deployAzServices: true
    env: env
    kubernetesVersion: kubernetesVersion
    location: location
    vnetName: vnetName
  }
}
