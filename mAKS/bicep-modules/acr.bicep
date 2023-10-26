// params
param name string
param location string = resourceGroup().location
param workspaceId string
param snetManagmentCrAgentsId string
param snetPrivateEndpointId string
param deployAzDiagnostics bool
param umi object

// Vars
var acrRoleDefId = '7f951dda-4ed3-4680-a7ca-43fe172d538d' // Acr Pull
var acrName = replace('acr${name}','-','')

// ACR
resource acr 'Microsoft.ContainerRegistry/registries@2023-08-01-preview' = {
  name: acrName
  location:location
  sku:{
    name:'Premium'
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
    name: location //geoRedundancyLocation
    location: location //geoRedundancyLocation
  }

  resource ap 'agentPools@2019-06-01-preview' = {
    name: 'acragent'
    location: location
    properties: {
      count: 1
      os: 'Linux'
      tier: 'S1'
      virtualNetworkSubnetResourceId: snetManagmentCrAgentsId
    }
  }
}

// Private endpoint
/*
@description('The network interface in the spoke vnet that enables privately connecting the AKS cluster with Container Registry.')
resource peCr 'Microsoft.Network/privateEndpoints@2022-05-01' = {
  name: 'pe-${acr.name}'
  location: location
  dependsOn: [
    acr::grl
  ]
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
} */

module pe 'privateendpoint.bicep' = {
  name: 'peDeploy-${acr.name}'
  params: {
    name: name
    location: location
    subnetId: snetPrivateEndpointId
    groupId: 'registry'
    destinationId: acr.id
  }
}

// Diagnostics
resource cr_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (deployAzDiagnostics) {
  scope: acr
  name: 'default'
  properties: {
    workspaceId: workspaceId
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

// RBAC
@description('Grant kubelet managed identity with container registry pull role permissions; this allows the AKS Cluster\'s kubelet managed identity to pull images from this container registry.')
resource setAcrRbac 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: acr
  name: 'rbacDeploy-${acr.name}'
  //name: guid(umi.outputs.id, acrRoleDefId, name)
  //  name: guid(resourceGroup().id, mc.id, containerRegistryPullRole.id)
  properties: {
    description: 'Allows AKS to pull container images from this ACR instance.'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', acrRoleDefId)
    principalId: umi.principalId
    principalType: 'ServicePrincipal'
  }
}

output acrId string = acr.id
