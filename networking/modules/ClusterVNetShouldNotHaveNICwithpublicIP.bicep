targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('The id of the cluster\'s virtual network')
@minLength(12)
param clusterVNetId string

/*** EXISTING RESOURCES ***/

resource policyResourceIdNoPublicIpsInVnet 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
    scope: subscription()
    name: guid(subscription().id, 'NoPublicIPsForNICsInVnet')
}

/*** RESOURCES ***/

@description('Cluster VNet should never have a NIC with a public IP. - Policy Assignment')
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' =  {
    name: guid(policyResourceIdNoPublicIpsInVnet.id, clusterVNetId) 
    properties: {
        displayName: 'Network interfaces in cluster [${last(split(clusterVNetId, '/'))}] should not have public IPs'
        description: 'Cluster VNet should never have a NIC with a public IP.'
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
