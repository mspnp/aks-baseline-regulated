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

/*** EXISTING RESOURCE GROUP RESOURCES ***/

@description('Spoke resource group')
resource targetResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  scope: subscription()
  name: '${split(targetVnetResourceId,'/')[4]}'
}

@description('The Spoke virtual network')
resource targetVirtualNetwork 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  scope: targetResourceGroup
  name: '${last(split(targetVnetResourceId,'/'))}'

  // Spoke virutual network's subnet for application gateway
  resource snetApplicationGateway 'subnets' existing = {
    name: 'snet-applicationgateway'
  }
}

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

  // The aks regulated in-cluster Tls certificate to establish https connections between your regional load balancer and your ingress controller enabling e2e tls connections
  resource kvsAppGwIngressInternalAksIngressTls 'secrets' = {
    name: 'agw-ingress-incluster-aks-ingress-contoso-com-tls'
    properties: {
      value: aksIngressControllerCertificate
    }
  }
}

@description('The aks regulated cluster log analytics workspace.')
resource law 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: 'law-${clusterName}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 90
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

@description('The regional load balancer resource that ingests all the client requests and forward them back to the aks regulated cluster after passing the configured WAF rules.')
resource agw 'Microsoft.Network/applicationGateways@2020-11-01' = {
  name: 'agw-${clusterName}'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${miAppGateway.id}': {
      }
    }
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
    }
    sslPolicy: {
      policyType: 'Custom'
      cipherSuites: [
        'TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384'
        'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256'
      ]
      minProtocolVersion: 'TLSv1_2'
    }
    trustedRootCertificates: [
      {
        name: 'root-cert-wildcard-aks-ingress-contoso'
        properties: {
          keyVaultSecretId: kv::kvsAppGwIngressInternalAksIngressTls.properties.secretUri
        }
      }
    ]
    gatewayIPConfigurations: [
      {
        name: 'agw-ip-configuration'
        properties: {
          subnet: {
            id: targetVirtualNetwork::snetApplicationGateway.id
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'agw-frontend-ip-configuration'
        properties: {
          publicIPAddress: {
            id: resourceId(subscription().subscriptionId, targetResourceGroup.name, 'Microsoft.Network/publicIpAddresses', 'pip-BU0001A0005-00')
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'agw-frontend-ports'
        properties: {
          port: 443
        }
      }
    ]
    autoscaleConfiguration: {
      minCapacity: 0
      maxCapacity: 10
    }
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Prevention'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.2'
      disabledRuleGroups: []
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
    }
    enableHttp2: false
    sslCertificates: [
      {
        name: 'agw-${clusterName}-ssl-certificate'
        properties: {
          keyVaultSecretId:  kv::kvsGatewaySslCert.properties.secretUri
        }
      }
    ]
    probes: [
      {
        name: 'probe-bu0001a0005-00.aks-ingress.contoso.com'
        properties: {
          protocol: 'Https'
          path: '/favicon.ico'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
          minServers: 0
          match: {
          }
        }
      }
      {
        name: 'ingress-controller'
        properties: {
          protocol: 'Https'
          path: '/healthz'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
          minServers: 0
          match: {
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'bu0001a0005-00.aks-ingress.contoso.com'
        properties: {
          backendAddresses: [
            {
              ipAddress: '10.240.4.4'
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'aks-ingress-contoso-backendpool-httpsettings'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          hostName: 'bu0001a0005-00.aks-ingress.contoso.com'
          pickHostNameFromBackendAddress: false
          requestTimeout: 20
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', 'agw-${clusterName}','probe-bu0001a0005-00.aks-ingress.contoso.com')
          }
          trustedRootCertificates: [
            {
              id: resourceId('Microsoft.Network/applicationGateways/trustedRootCertificates', 'agw-${clusterName}','root-cert-wildcard-aks-ingress-contoso')
            }
          ]
        }
      }
    ]
    httpListeners: [
      {
        name: 'listener-https'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', 'agw-${clusterName}','agw-frontend-ip-configuration')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', 'agw-${clusterName}','agw-frontend-ports')
          }
          protocol: 'Https'
          sslCertificate: {
            id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', 'agw-${clusterName}','agw-${clusterName}-ssl-certificate')
          }
          hostName: 'bicycle.contoso.com'
          hostNames: []
          requireServerNameIndication: true
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'agw-routing-rules'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', 'agw-${clusterName}','listener-https')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', 'agw-${clusterName}','bu0001a0005-00.aks-ingress.contoso.com')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', 'agw-${clusterName}','aks-ingress-contoso-backendpool-httpsettings')
          }
        }
      }
    ]
  }
}

@description('The diagnostic settings configuration for the aks regulated cluster regional load balancer.')
resource agw_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: agw
  name: 'default'
  properties: {
    workspaceId: law.id
    logs: [
      {
        category: 'ApplicationGatewayAccessLog'
        enabled: true
      }
      {
        category: 'ApplicationGatewayPerformanceLog'
        enabled: true
      }
      {
        category: 'ApplicationGatewayFirewallLog'
        enabled: true
      }
    ]
  }
}

/*** OUTPUTS ***/

output agwName string = agw.name
