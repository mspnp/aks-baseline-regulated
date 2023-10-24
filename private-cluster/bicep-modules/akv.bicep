
param name string
param location string


var akvRoleDefId = '4633458b-17de-408a-b874-0445c86b69e6' // Secrets user

resource umi 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: 'umi-${name}'
}

resource akv 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name : 'akv-${name}'
  location : location
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
  }
}

// Diagnostics

resource akv_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: akv
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

// Private endpoint

/*@description('The network interface in the spoke vnet that enables privately connecting the AKS cluster with Key Vault.')
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
}*/

module pe 'privateendpoint.bicep' = {
  name: 'peDeploy-${akv.name}'
  params: {
    name: name
    location: location
    subnetId: 
    groupId: 'vault'
    destinationId: akv.id
    privateDnsZoneName: 
  }
}

// RBAC

resource setAkvRbac 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: akv
  name: guid(umi.id, akvRoleDefId, name)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', akvRoleDefId)
    principalId: umi.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output akvId string = akv.id
