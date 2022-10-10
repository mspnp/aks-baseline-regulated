targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('The regional network spoke VNet Resource ID that the cluster will be joined to')
@minLength(79)
param targetVnetResourceId string

@description('Azure AD Group in the identified tenant that will be granted the highly privileged cluster-admin role.')
param clusterAdminAadGroupObjectId string

@description('Your AKS control plane Cluster API authentication tenant')
param k8sControlPlaneAuthorizationTenantId string

@description('The certificate data for app gateway TLS termination. It is base64')
param appGatewayListenerCertificate string

@description('The base 64 encoded AKS Ingress Controller public certificate (as .crt or .cer) to be stored in Azure Key Vault as secret and referenced by Azure Application Gateway as a trusted root certificate.')
param aksIngressControllerCertificate string

@allowed([
  'australiaeast'
  'canadacentral'
  'centralus'
  'eastus'
  'eastus2'
  'westus2'
  'francecentral'
  'germanywestcentral'
  'northeurope'
  'southafricanorth'
  'southcentralus'
  'uksouth'
  'westeurope'
  'japaneast'
  'southeastasia'
])
@description('AKS Service, Node Pools, and supporting services (KeyVault, App Gateway, etc) region. This needs to be the same region as the vnet provided in these parameters.')
@minLength(4)
param location string

@allowed([
  'australiasoutheast'
  'canadaeast'
  'eastus2'
  'westus'
  'centralus'
  'westcentralus'
  'francesouth'
  'germanynorth'
  'westeurope'
  'ukwest'
  'northeurope'
  'japanwest'
  'southafricawest'
  'northcentralus'
  'eastasia'
  'eastus'
  'westus2'
  'francecentral'
  'uksouth'
  'japaneast'
  'southeastasia'
])
@description('For Azure resources that support native geo-redunancy, provide the location the redundant service will have its secondary. Should be different than the location parameter and ideally should be a paired region - https://learn.microsoft.com/azure/best-practices-availability-paired-regions. This region does not need to support availability zones.')
@minLength(4)
param geoRedundancyLocation string

@description('The Azure resource ID of a VM image that will be used for the jump box.')
@minLength(70)
param jumpBoxImageResourceId string

@description('A cloud init file (starting with #cloud-config) as a base 64 encoded string used to perform image customization on the jump box VMs. Used for user-management in this context.')
@minLength(100)
param jumpBoxCloudInitAsBase64 string = '10.200.0.0/26'

/*** VARIABLES ***/

var subRgUniqueString = uniqueString('aks', subscription().subscriptionId, resourceGroup().id)
var clusterName = 'aks-${subRgUniqueString}'

/*** EXISTING RESOURCES ***/

@description('Built-in Azure RBAC role that must be applied to the kublet Managed Identity allowing it to further assign adding managed identities to the cluster\'s underlying VMSS.')
resource managedIdentityOperatorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'f1a07417-d97a-45cb-824c-7a7467783830'
  scope: subscription()
}

/*** RESOURCES ***/

@description('The control plane identity used by the cluster.')
resource miClusterControlPlane 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: 'mi-${clusterName}-controlplane'
  location: location
}

@description('The in-cluster ingress controller identity used by pod identity agent to acquire access tokens to read ssl certs from Azure KeyVault.')
resource miIngressController 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: 'mi-${clusterName}-ingresscontroller'
  location: location
}

@description('The regional load balancer identity used by your Application Gateway instance to acquire access tokens to read ssl certs and secrets from Azure KeyVault.')
resource miAppGateway 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: 'mi-appgateway'
  location: location
}

@description('Grant the cluster control plane managed identity with managed identity operator role permissions; this allows to assign compute with the ingress controller managed identity; this is required for Azure Pod Idenity.')
resource icMiClusterControlPlaneManagedIdentityOperatorRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: miIngressController
  name: guid(resourceGroup().id, miClusterControlPlane.name, managedIdentityOperatorRole.id)
  properties: {
    roleDefinitionId: managedIdentityOperatorRole.id
    principalId: miClusterControlPlane.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

@description('The secret storage management resource for the aks regulated cluster.')
resource kv 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: 'kv-${clusterName}'
  location: location
  properties: {
    accessPolicies: [
      {
        tenantId: miAppGateway.properties.tenantId
        objectId: miAppGateway.properties.principalId
        permissions: {
          secrets: [
            'get'
          ]
          certificates: [
            'get'
          ]
          keys: []
        }
      }
      {
        tenantId: miIngressController.properties.tenantId
        objectId: miIngressController.properties.principalId
        permissions: {
          secrets: [
            'get'
          ]
          certificates: [
            'get'
          ]
          keys: []
        }
      }
    ]
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableSoftDelete: true
  }

  // The internet facing Tls certificate to establish https connections between your clients and your regional load balancer
  resource kvsGatewaySslCert 'secrets' = {
    name: 'sslcert'
    properties: {
      value: appGatewayListenerCertificate
    }
  }
}
