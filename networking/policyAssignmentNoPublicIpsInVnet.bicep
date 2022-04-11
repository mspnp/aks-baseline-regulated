targetScope = 'subscription'

/*** PARAMETERS ***/

@description('The name of the Virtual Network that contains the AKS cluster')
param clusterVNetName string

@description('The resourceId of the Virtual Network that contains the AKS cluster')
param clusterVNetId string

/*** RESOURCES ***/

resource policyResourceIdNoPublicIpsInVnet 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  scope: subscription()
  name: 'NoPublicIPsForNICsInVnet'
}

@description('Cluster VNet should never have a NIC with a public IP.')
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' =  {
    name: guid(policyResourceIdNoPublicIpsInVnet.id, clusterVNetId)
    scope: subscription()
    properties: {
        displayName: 'Network interfaces in [${clusterVNetName}] should not have public IPs'
        notScopes: []
        policyDefinitionId: policyResourceIdNoPublicIpsInVnet.id
        parameters: {
            vnetResourceId: {
                value: clusterVNetId
            }
        }
        nonComplianceMessages: [
            {
                message: 'No NICs with public IPs are allowed in the regulated environment spoke.'
            }
        ]
    }
}
