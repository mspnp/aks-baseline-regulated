targetScope = 'subscription'

/*** PARAMETERS ***/

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
@description('The policy assignment\'s location.')
param location string

@description('The name of the cluster\'s virtual network')
param clusterVNetName string

@description('The id of the cluster\'s virtual network')
param clusterVNetId string

/*** RESOURCES ***/

resource policyResourceIdNoPublicIpsInVnet 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
    scope: subscription()
    name: 'NoPublicIPsForNICsInVnet'
}

@description('Cluster VNet should never have a NIC with a public IP. - Policy Assignment')
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' =  {
    name: guid(policyResourceIdNoPublicIpsInVnet.id, clusterVNetId)
    location: location
    properties: {
        scope: subscription().id
        displayName: 'Network interfaces in [${clusterVNetName}] should not have public IPs'
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
