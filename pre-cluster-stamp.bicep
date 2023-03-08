targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('The regional network spoke VNet Resource ID that the cluster will be joined to')
@minLength(79)
param targetVnetResourceId string

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
param location string = 'eastus2'

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
param geoRedundancyLocation string = 'centralus'

@description('The Base64 encoded AKS ingress controller\'s public certificate (as .crt or .cer) to be stored in Azure Key Vault as secret and referenced by Azure Application Gateway as a trusted root certificate.')
@minLength(35)
param aksIngressControllerCertificate string

/*** VARIABLES ***/

var subRgUniqueString = uniqueString('aks', subscription().subscriptionId, resourceGroup().id)
var clusterName = 'aks-${subRgUniqueString}'
var acrName = 'acraks${subRgUniqueString}'

/*** EXISTING RESOURCES ***/

@description('Built-in Azure RBAC role that is applied to a Key Vault to grant with secrets content read privileges. Granted to both Key Vault and our workload\'s identity.')
resource keyVaultSecretsUserRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '4633458b-17de-408a-b874-0445c86b69e6'
  scope: subscription()
}

@description('Built-in Azure RBAC role that is applied a Key Vault to grant with metadata, certificates, keys and secrets read privileges. Granted to App Gateway\'s managed identity.')
resource keyVaultReaderRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '21090545-7ca7-4776-b22c-e363652d74d2'
  scope: subscription()
}

@description('Spoke resource group')
resource spokeResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  scope: subscription()
  name: '${split(targetVnetResourceId, '/')[4]}'
}

@description('The Spoke virtual network')
resource vnetSpoke 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  scope: spokeResourceGroup
  name: '${last(split(targetVnetResourceId, '/'))}'

  // Spoke virutual network's subnet for all private endpoints
  resource snetPrivatelinkendpoints 'subnets' existing = {
    name: 'snet-privatelinkendpoints'
  }

  // spoke virtual network's subnet for managment acr agent pools
  resource snetManagmentCrAgents 'subnets' existing = {
    name: 'snet-management-acragents'
  }
}

resource pdzCr 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  scope: spokeResourceGroup
  name: 'privatelink.azurecr.io'
}

resource pdzKv 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  scope: spokeResourceGroup
  name: 'privatelink.vaultcore.azure.net'
}

/*** RESOURCES ***/

@description('The AKS cluster and related resources log analytics workspace.')
resource la 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: 'la-${clusterName}'
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

@description('The private container registry for the aks regulated cluster.')
resource acr 'Microsoft.ContainerRegistry/registries@2022-02-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: false
    networkRuleSet: {
      defaultAction: 'Deny'
      ipRules: []
    }
    policies: {
      quarantinePolicy: {
        status: 'disabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: 'enabled'
      }
      retentionPolicy: {
        days: 15
        status: 'enabled'
      }
    }
    publicNetworkAccess: 'Disabled'
    encryption: {
      status: 'disabled'
    }
    dataEndpointEnabled: true
    networkRuleBypassOptions: 'AzureServices'
    zoneRedundancy: 'Enabled'
  }

  resource grl 'replications' = {
    name: geoRedundancyLocation
    location: geoRedundancyLocation
  }

  resource ap 'agentPools@2019-06-01-preview' = {
    name: 'acragent'
    location: location
    properties: {
      count: 1
      os: 'Linux'
      tier: 'S1'
      virtualNetworkSubnetResourceId: vnetSpoke::snetManagmentCrAgents.id
    }
  }
}

resource cr_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: acr
  name: 'default'
  properties: {
    workspaceId: la.id
    metrics: [
      {
        timeGrain: 'PT1M'
        category: 'AllMetrics'
        enabled: true
      }
    ]
    logs: [
      {
        category: 'ContainerRegistryRepositoryEvents'
        enabled: true
      }
      {
        category: 'ContainerRegistryLoginEvents'
        enabled: true
      }
    ]
  }
}

@description('The network interface in the spoke vnet that enables privately connecting the AKS cluster with Container Registry.')
resource peCr 'Microsoft.Network/privateEndpoints@2022-05-01' = {
  name: 'pe-${acr.name}'
  location: location
  properties: {
    subnet: {
      id: vnetSpoke::snetPrivatelinkendpoints.id
    }
    privateLinkServiceConnections: [
      {
        name: 'to-${vnetSpoke.name}'
        properties: {
          privateLinkServiceId: acr.id
          groupIds: [
            'registry'
          ]
        }
      }
    ]
  }
  dependsOn: [
    acr::grl
  ]

  resource pdzg 'privateDnsZoneGroups' = {
    name: 'for-${acr.name}'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'privatelink-azurecr-io'
          properties: {
            privateDnsZoneId: pdzCr.id
          }
        }
      ]
    }
  }
}

@description('The scheduled query that returns images being imported from repositories different than quarantine/')
resource sqrNonQuarantineImportedImgesToCr 'Microsoft.Insights/scheduledQueryRules@2022-06-15' = {
  name: 'Image Imported into ACR from ${acr.name} source other than approved Quarantine'
  location: location
  properties: {
    description: 'The only images we want in live/ are those that came from this ACR instance, but from the quarantine/ repository.'
    actions: {
      actionGroups: []
    }
    criteria: {
      allOf: [
        {
          operator: 'GreaterThan'
          query: 'ContainerRegistryRepositoryEvents\r\n| where OperationName == "importImage" and Repository startswith "live/" and MediaType !startswith strcat(_ResourceId, "/quarantine")'
          threshold: 0
          timeAggregation: 'Count'
          dimensions: []
          failingPeriods: {
            minFailingPeriodsToAlert: 1
            numberOfEvaluationPeriods: 1
          }
          resourceIdColumn: ''
        }
      ]
    }
    enabled: true
    evaluationFrequency: 'PT10M'
    scopes: [
      acr.id
    ]
    severity: 3
    windowSize: 'PT10M'
    muteActionsDuration: null
    overrideQueryTimeRange: null
  }
  dependsOn: [
    cr_diagnosticSettings
  ]
}

@description('The secret storage management resource for the AKS regulated cluster.')
resource kv 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: 'kv-${clusterName}'
  location: location
  properties: {
    accessPolicies: [] // Azure RBAC is used instead
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    networkAcls: {
      bypass: 'AzureServices' // Required for AppGW communication
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
    enableRbacAuthorization: true
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    createMode: 'default'
    publicNetworkAccess: 'Disabled'
  }
}

@description('The in-cluster ingress controller identity used by the pod identity agent to acquire access tokens to read SSL certs from Azure Key Vault.')
resource miIngressController 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: 'mi-${clusterName}-ingresscontroller'
  location: location
}

@description('Grant the ingress controller\'s managed identity with Key Vault secrets user role permissions; this allows pulling secrets from Key Vault.')
resource kvMiIngressControllerSecretsUserRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: kv
  name: guid(resourceGroup().id, miIngressController.name, keyVaultSecretsUserRole.id)
  properties: {
    roleDefinitionId: keyVaultSecretsUserRole.id
    principalId: miIngressController.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

@description('Grant the ingress controller\'s managed identity with Key Vault reader role permissions; this allows pulling frontend and backend certificates.')
resource kvMiIngressControllerKeyVaultReader_roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: kv
  name: guid(resourceGroup().id, miIngressController.name, keyVaultReaderRole.id)
  properties: {
    roleDefinitionId: keyVaultReaderRole.id
    principalId: miIngressController.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource kvsAppGwIngressInternalAksIngressTls 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: kv
  name: 'agw-ingress-internal-aks-ingress-contoso-com-tls'
  properties: {
    value: aksIngressControllerCertificate
  }
  dependsOn: [
    miIngressController
  ]
}

resource kv_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: kv
  name: 'default'
  properties: {
    workspaceId: la.id
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

@description('The network interface in the spoke vnet that enables privately connecting the AKS cluster with Key Vault.')
resource peKv 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: 'pe-${kv.name}'
  location: location
  properties: {
    subnet: {
      id: vnetSpoke::snetPrivatelinkendpoints.id
    }
    privateLinkServiceConnections: [
      {
        name: 'to-${vnetSpoke.name}'
        properties: {
          privateLinkServiceId: kv.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }

  resource pdzg 'privateDnsZoneGroups' = {
    name: 'for-${kv.name}'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'privatelink-akv-net'
          properties: {
            privateDnsZoneId: pdzKv.id
          }
        }
      ]
    }
  }
}

/*** OUTPUTS ***/

output quarantineContainerRegistryName string = acr.name
output containerRegistryName string = acr.name
output keyVaultName string = kv.name
output ingressClientid string = miIngressController.properties.clientId
