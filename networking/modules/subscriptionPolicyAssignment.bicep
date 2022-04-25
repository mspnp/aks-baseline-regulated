targetScope = 'subscription'

/*** PARAMETERS ***/

@description('Subsription deployment\'s main location.')
@minLength(4)
param location string

@description('The id of the cluster\'s virtual network')
@minLength(12)
param clusterVNetId string

@description('The name of the cluster\'s virtual network')
@minLength(1)
param clusterVNetName string

/*** EXISTING RESOURCES ***/

resource policyResourceIdNoPublicIpsInVnet 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
    scope: subscription()
    name: 'NoPublicIPsForNICsInVnet'
}

/*** RESOURCES ***/

@description('Cluster VNet should never have a NIC with a public IP. - Policy Assignment')
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' =  {
    name: guid(policyResourceIdNoPublicIpsInVnet.id, clusterVNetId)
    location: location
    scope: subscription()
    properties: {
        displayName: 'Network interfaces in cluster [${clusterVNetName}] should not have public IPs'
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
