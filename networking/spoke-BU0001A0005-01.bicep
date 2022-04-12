targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('The regional hub network to which this regional spoke will peer to.')
@minLength(79)
param hubVnetResourceId string

@description('The organization\'s application ID')
param orgAppId string = 'BU0001A0005'

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
@description('The spokes\'s regional affinity, must be the same as the hub\'s location. All resources tied to this spoke will also be homed in this region. The network team maintains this approved regional list which is a subset of zones with Availability Zone support.')
param location string

@description('Flow Logs are enabled by default, if for some reason they cause conflicts with flow log policies already in place in your subscription, you can disable them by passing "false" to this parameter.')
param deployFlowLogResources bool = true

/*** RESOURCES ***/

@description('The resource group name containing virtual network in which the regional Azure Firewall is deployed.')
resource rgHubs 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  scope: subscription()
  name: split(hubVnetResourceId, '/')[4]
}

@description('The regional Azure Firewall that all regional spoke networks can egress through.')
resource hubFirewall 'Microsoft.Network/azureFirewalls@2021-05-01' existing = {
  scope: rgHubs
  name: 'fw-${location}'
}

@description('Next hop to regional hub Azure Firewall')
resource afRouteTable 'Microsoft.Network/routeTables@2021-05-01' = {
    name: 'route-to-${location}-hub-fw'
    location: location
    properties: {
        routes: [
            {
                name: 'r-nexthop-to-fw'
                properties: {
                    nextHopType: 'VirtualAppliance'
                    addressPrefix: '0.0.0.0/0'
                    nextHopIpAddress: hubFirewall.properties.ipConfigurations[0].properties.privateIPAddress
                }
            }
        ]
    }
}

resource azureBastionSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' existing = {
    scope: rgHubs
    name: 'subnets/AzureBastionSubnet'
  }

@description('NSG blocking all inbound traffic other than port 22 for jumpbox access.')
resource nsgAllowSshFromHubBastionInBound 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
    name: 'nsg-vnet-spoke-${orgAppId}-01-management-ops'
    location: location
    properties: {
        securityRules: [
            {
                name: 'AllowSshFromHubBastionInBound'
                properties: {
                    description: 'Allow our Azure Bastion users in.'
                    protocol: 'Tcp'
                    sourcePortRange: '*'
                    sourceAddressPrefix: azureBastionSubnet.properties.addressPrefix
                    destinationPortRange: '22'
                    destinationAddressPrefix: '*'
                    access: 'Allow'
                    priority: 100
                    direction: 'Inbound'
                }
            }
            {
                name: 'DenyAllInBound'
                properties: {
                    description: 'Deny remaining traffic.'
                    protocol: '*'
                    sourcePortRange: '*'
                    sourceAddressPrefix: '*'
                    destinationPortRange: '*'
                    destinationAddressPrefix: '*'
                    access: 'Deny'
                    priority: 1000
                    direction: 'Inbound'
                }
            }
            {
                name: 'Allow443InternetOutBound'
                properties: {
                    protocol: 'Tcp'
                    sourcePortRange: '*'
                    sourceAddressPrefix: '*'
                    destinationPortRange: '443'
                    destinationAddressPrefix: 'Internet'
                    access: 'Allow'
                    priority: 100
                    direction: 'Outbound'
                }
            }
            {
                name: 'Allow443VnetOutBound'
                properties: {
                    protocol: 'Tcp'
                    sourcePortRange: '*'
                    sourceAddressPrefix: 'VirtualNetwork'
                    destinationPortRange: '443'
                    destinationAddressPrefix: 'VirtualNetwork'
                    access: 'Allow'
                    priority: 110
                    direction: 'Outbound'
                }
            }
            {
                name: 'DenyAllOutBound'
                properties: {
                    protocol: '*'
                    sourcePortRange: '*'
                    sourceAddressPrefix: '*'
                    destinationPortRange: '*'
                    destinationAddressPrefix: '*'
                    access: 'Deny'
                    priority: 1000
                    direction: 'Outbound'
                }
            }
        ]
    }
}

resource hubLaWorkspace 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' existing = {
    scope: rgHubs
    name: 'la-hub-${location}'
}

resource nsgAllowSshFromHubBastionInBound_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
    name: 'toHub'
    scope: nsgAllowSshFromHubBastionInBound
    properties: {
        workspaceId: hubLaWorkspace.id
        logs: [
            {
                category: 'NetworkSecurityGroupEvent'
                enabled: true
            }
            {
                category: 'NetworkSecurityGroupRuleCounter'
                enabled: true
            }
        ]
    }
}

@description('NSG on all AKS system nodepools. Feel free to constrict further both inbound and outbound!')
resource nsgAksSystemNodepools 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
    name: 'nsg-vnet-spoke-${orgAppId}-01-system-nodepools'
    location: location
    properties: {
        securityRules: [
            {
                name: 'DenySshInBound'
                properties: {
                    description: 'No SSH access allowed to nodes.'
                    protocol: 'Tcp'
                    sourcePortRange: '*'
                    sourceAddressPrefix: '*'
                    destinationPortRange: '22'
                    destinationAddressPrefix: '*'
                    access: 'Deny'
                    priority: 100
                    direction: 'Inbound'
                }
            }
        ]
    }
}

resource nsgAksSystemNodepools_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
    name: 'toHub'
    scope: nsgAksSystemNodepools
    properties: {
        workspaceId: hubLaWorkspace.id
        logs: [
            {
                category: 'NetworkSecurityGroupEvent'
                enabled: true
            }
            {
                category: 'NetworkSecurityGroupRuleCounter'
                enabled: true
            }
        ]
    }
}

@description('NSG on the AKS in-scope nodepools. Feel free to constrict further both inbound and outbound!')
resource nsgAksInScopeNodepools 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
    name: 'nsg-vnet-spoke-${orgAppId}-01-is-nodepools'
    location: location
    properties: {
        securityRules: [
            {
                name: 'DenySshInBound'
                properties: {
                    description: 'No SSH access allowed to nodes.'
                    protocol: 'Tcp'
                    sourcePortRange: '*'
                    sourceAddressPrefix: '*'
                    destinationPortRange: '22'
                    destinationAddressPrefix: '*'
                    access: 'Deny'
                    priority: 100
                    direction: 'Inbound'
                }
            }
        ]
    }
}

resource nsgAksInScopeNodepools_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
    name: 'toHub'
    scope: nsgAksInScopeNodepools
    properties: {
        workspaceId: hubLaWorkspace.id
        logs: [
            {
                category: 'NetworkSecurityGroupEvent'
                enabled: true
            }
            {
                category: 'NetworkSecurityGroupRuleCounter'
                enabled: true
            }
        ]
    }
}

@description('NSG on the AKS out-of-scope nodepools. Feel free to constrict further both inbound and outbound!')
resource nsgAksOutOfScopeNodepools 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
    name: 'nsg-vnet-spoke-${orgAppId}-01-oos-nodepools'
    location: location
    properties: {
        securityRules: [
            {
                name: 'DenySshInBound'
                properties: {
                    description: 'No SSH access allowed to nodes.'
                    protocol: 'Tcp'
                    sourcePortRange: '*'
                    sourceAddressPrefix: '*'
                    destinationPortRange: '22'
                    destinationAddressPrefix: '*'
                    access: 'Deny'
                    priority: 100
                    direction: 'Inbound'
                }
            }
        ]
    }
}

resource nsgAksOutOfScopeNodepools_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
    name: 'toHub'
    scope: nsgAksOutOfScopeNodepools
    properties: {
        workspaceId: hubLaWorkspace.id
        logs: [
            {
                category: 'NetworkSecurityGroupEvent'
                enabled: true
            }
            {
                category: 'NetworkSecurityGroupRuleCounter'
                enabled: true
            }
        ]
    }
}

@description('Default NSG on the private link subnet. No traffic should be allowed out, and only Tcp/443 in. Key Vault and Container Registry is expected to be accessed in here.')
resource nsgAksPrivateLinkEndpoint 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
    name: 'nsg-vnet-spoke-${orgAppId}-01-privatelinkendpoints'
    location: location
    properties: {
        securityRules: [
            {
                name: 'AllowAll443InFromVnet'
                properties: {
                    protocol: 'Tcp'
                    sourcePortRange: '*'
                    sourceAddressPrefix: 'VirtualNetwork'
                    destinationPortRange: '443'
                    destinationAddressPrefix: 'VirtualNetwork'
                    access: 'Allow'
                    priority: 100
                    direction: 'Inbound'
                }
            }
            {
                name: 'DenyAllInBound'
                properties: {
                    protocol: '*'
                    sourcePortRange: '*'
                    sourceAddressPrefix: '*'
                    destinationPortRange: '*'
                    destinationAddressPrefix: '*'
                    access: 'Deny'
                    priority: 1000
                    direction: 'Inbound'
                }
            }
            {
                name: 'DenyAllOutBound'
                properties: {
                    protocol: '*'
                    sourcePortRange: '*'
                    sourceAddressPrefix: '*'
                    destinationPortRange: '*'
                    destinationAddressPrefix: '*'
                    access: 'Deny'
                    priority: 1000
                    direction: 'Outbound'
                }
            }
        ]
    }
}

resource nsgAksPrivateLinkEndpoint_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
    name: 'toHub'
    scope: nsgAksPrivateLinkEndpoint
    properties: {
        workspaceId: hubLaWorkspace.id
        logs: [
            {
                category: 'NetworkSecurityGroupEvent'
                enabled: true
            }
            {
                category: 'NetworkSecurityGroupRuleCounter'
                enabled: true
            }
        ]
    }
}

@description('Default NSG on the AKS ILB subnet. Feel free to constrict further!')
resource nsgAksDefaultILBSubnet 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
    name: 'nsg-vnet-spoke-${orgAppId}-01-akslibs'
    location: location
    properties: {
        securityRules: [
        ]
    }
}

resource nsgAksDefaultILBSubnet_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
    name: 'toHub'
    scope: nsgAksDefaultILBSubnet
    properties: {
        workspaceId: hubLaWorkspace.id
        logs: [
            {
                category: 'NetworkSecurityGroupEvent'
                enabled: true
            }
            {
                category: 'NetworkSecurityGroupRuleCounter'
                enabled: true
            }
        ]
    }
}

@description('NSG on the App Gateway subnet.')
resource nsgAppGatewaySubnet 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
    name: 'nsg-vnet-spoke-${orgAppId}-01-appgw'
    location: location
    properties: {
        securityRules: [
            {
                name: 'Allow443InBound'
                properties: {
                    description: 'Allow ALL web traffic into 443. (If you wanted to allow-list specific IPs, this is where you\'d list them.)'
                    protocol: 'Tcp'
                    sourcePortRange: '*'
                    sourceAddressPrefix: 'Internet'
                    destinationPortRange: '443'
                    destinationAddressPrefix: 'VirtualNetwork'
                    access: 'Allow'
                    priority: 100
                    direction: 'Inbound'
                }
            }
            {
                name: 'AllowControlPlaneInBound'
                properties: {
                    description: 'Allow Azure Control Plane in. (https://docs.microsoft.com/azure/application-gateway/configuration-infrastructure#network-security-groups)'
                    protocol: '*'
                    sourcePortRange: '*'
                    sourceAddressPrefix: '*'
                    destinationPortRange: '65200-65535'
                    destinationAddressPrefix: '*'
                    access: 'Allow'
                    priority: 110
                    direction: 'Inbound'
                }
            }
            {
                name: 'AllowHealthProbesInBound'
                properties: {
                    description: 'Allow Azure Health Probes in. (https://docs.microsoft.com/azure/application-gateway/configuration-infrastructure#network-security-groups)'
                    protocol: '*'
                    sourcePortRange: '*'
                    sourceAddressPrefix: 'AzureLoadBalancer'
                    destinationPortRange: '*'
                    destinationAddressPrefix: 'VirtualNetwork'
                    access: 'Allow'
                    priority: 120
                    direction: 'Inbound'
                }
            }
            {
                name: 'DenyAllInBound'
                properties: {
                    protocol: '*'
                    sourcePortRange: '*'
                    sourceAddressPrefix: '*'
                    destinationPortRange: '*'
                    destinationAddressPrefix: '*'
                    access: 'Deny'
                    priority: 1000
                    direction: 'Inbound'
                }
            }
            {
                name: 'AllowAllOutBound'
                properties: {
                    protocol: '*'
                    sourcePortRange: '*'
                    sourceAddressPrefix: '*'
                    destinationPortRange: '*'
                    destinationAddressPrefix: '*'
                    access: 'Allow'
                    priority: 1000
                    direction: 'Outbound'
                }
            }
        ]
    }
}

resource nsgAppGatewaySubnet_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
    name: 'toHub'
    scope: nsgAppGatewaySubnet
    properties: {
        workspaceId: hubLaWorkspace.id
        logs: [
            {
                category: 'NetworkSecurityGroupEvent'
                enabled: true
            }
            {
                category: 'NetworkSecurityGroupRuleCounter'
                enabled: true
            }
        ]
    }
}

@description('NSG on the ACR docker subnet.')
resource nsgAcrDockerSubnet 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
    name: 'nsg-vnet-spoke-${orgAppId}-01-acragents'
    location: location
    properties: {
        securityRules: [
            {
                name: 'AllowKeyVaultOutBound'
                properties: {
                    description: 'Allow KeyVault Access'
                    protocol: 'Tcp'
                    sourcePortRange: '*'
                    sourceAddressPrefix: 'VirtualNetwork'
                    destinationPortRange: '443'
                    destinationAddressPrefix: 'AzureKeyVault'
                    access: 'Allow'
                    priority: 100
                    direction: 'Outbound'
                }
            }
            {
                name: 'AllowStorageOutBound'
                properties: {
                    description: 'Allow Storage Access'
                    protocol: 'Tcp'
                    sourcePortRange: '*'
                    sourceAddressPrefix: 'VirtualNetwork'
                    destinationPortRange: '443'
                    destinationAddressPrefix: 'Storage'
                    access: 'Allow'
                    priority: 110
                    direction: 'Outbound'
                }
            }
            {
                name: 'AllowEventHubOutBound'
                properties: {
                    description: 'Allow EventHub Access'
                    protocol: 'Tcp'
                    sourcePortRange: '*'
                    sourceAddressPrefix: 'VirtualNetwork'
                    destinationPortRange: '443'
                    destinationAddressPrefix: 'EventHub'
                    access: 'Allow'
                    priority: 120
                    direction: 'Outbound'
                }
            }
            {
                name: 'AllowAadOutBound'
                properties: {
                    description: 'Allow Azure Active Directory Access'
                    protocol: 'Tcp'
                    sourcePortRange: '*'
                    sourceAddressPrefix: 'VirtualNetwork'
                    destinationPortRange: '443'
                    destinationAddressPrefix: 'AzureActiveDirectory'
                    access: 'Allow'
                    priority: 130
                    direction: 'Outbound'
                }
            }
            {
                name: 'AllowAzureMonitorBound'
                properties: {
                    description: 'Allow Azure Active Directory Access'
                    protocol: 'Tcp'
                    sourcePortRange: '*'
                    sourceAddressPrefix: 'VirtualNetwork'
                    destinationPortRange: '443'
                    destinationAddressPrefix: 'AzureMonitor'
                    access: 'Allow'
                    priority: 140
                    direction: 'Outbound'
                }
            }
        ]
    }
}

resource nsgAcrDockerSubnet_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
    name: 'toHub'
    scope: nsgAcrDockerSubnet
    properties: {
        workspaceId: hubLaWorkspace.id
        logs: [
            {
                category: 'NetworkSecurityGroupEvent'
                enabled: true
            }
            {
                category: 'NetworkSecurityGroupRuleCounter'
                enabled: true
            }
        ]
    }
}

resource policyResourceIdNoPublicIpsInVnet 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
    scope: subscription()
    name: 'NoPublicIPsForNICsInVnet'
  }

@description('Deploys subscription-level policy related to spoke deployment.')
module policyAssignmentNoPublicIpsInVnet 'modules/SubscriptionSpokePipUsagePolicyDeployment.bicep' = {
    name: 'Apply-Subscription-Spoke-PipUsage-Policies-01'
    scope: subscription()
    params: {
        name: guid(policyResourceIdNoPublicIpsInVnet.id, clusterVNet.id)
        displayName: 'Network interfaces in [${clusterVNet.name}] should not have public IPs'
        location: location
        policyAssignmentDescription: 'Cluster VNet should never have a NIC with a public IP.'
        parameters: {
            vnetResourceId: {
                value: clusterVNet.id
            }
        }
        policyDefinitionId: policyResourceIdNoPublicIpsInVnet.id
        nonComplianceMessages: [
            {
                message: 'No NICs with public IPs are allowed in the regulated environment spoke.'
            }
        ]
    }
}

@description('cluster\'s virtual network. 65,536 (-reserved) IPs available to the workload, split across four subnets for AKS, one for App Gateway, and two for management.')
resource clusterVNet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
    name: 'vnet-spoke-${orgAppId}-01'
    location: location
    properties: {
        addressSpace: {
            addressPrefixes: [
                '10.240.0.0/16'
            ]
        }
        subnets: [
            {
                name: 'snet-cluster-systemnodepool'
                properties: {
                    addressPrefix: '10.240.8.0/22'
                    routeTable: {
                        id: afRouteTable.id
                    }
                    networkSecurityGroup: {
                        id: nsgAksSystemNodepools.id
                    }
                    privateEndpointNetworkPolicies: 'Disabled'
                    privateLinkServiceNetworkPolicies: 'Disabled'
                }
            }
            {
                name: 'snet-cluster-inscopenodepools'
                properties: {
                    addressPrefix: '10.240.12.0/22'
                    networkSecurityGroup: {
                        id: nsgAksInScopeNodepools.id
                    }
                    routeTable: {
                        id: afRouteTable.id
                    }
                    privateEndpointNetworkPolicies: 'Disabled'
                    privateLinkServiceNetworkPolicies: 'Disabled'
                }
            }
            {
                name: 'snet-cluster-outofscopenodepools'
                properties: {
                    addressPrefix: '10.240.16.0/22'
                    networkSecurityGroup: {
                        id: nsgAksOutOfScopeNodepools.id
                    }
                    routeTable: {
                        id: afRouteTable.id
                    }
                    privateEndpointNetworkPolicies: 'Disabled'
                    privateLinkServiceNetworkPolicies: 'Disabled'
                }
            }
            {
                name: 'snet-cluster-ingressservices'
                properties: {
                    addressPrefix: '10.240.4.0/28'
                    networkSecurityGroup: {
                        id: nsgAksDefaultILBSubnet.id
                    }
                    privateEndpointNetworkPolicies: 'Disabled'
                    privateLinkServiceNetworkPolicies: 'Disabled'
                }
            }
            {
                name: 'snet-applicationgateway'
                properties: {
                    addressPrefix: '10.240.5.0/24'
                    networkSecurityGroup: {
                        id: nsgAppGatewaySubnet.id
                    }
                    privateEndpointNetworkPolicies: 'Disabled'
                    privateLinkServiceNetworkPolicies: 'Disabled'
                }
            }
            {
                name: 'snet-management-ops'
                properties: {
                    addressPrefix: '10.240.1.0/28'
                    routeTable: {
                        id: afRouteTable.id
                    }
                    networkSecurityGroup: {
                        id: nsgAllowSshFromHubBastionInBound.id
                    }
                    privateEndpointNetworkPolicies: 'Disabled'
                    privateLinkServiceNetworkPolicies: 'Disabled'
                }
            }
            {
                name: 'snet-management-agents'
                properties: {
                    addressPrefix: '10.240.2.0/26'
                    routeTable: {
                        id: afRouteTable.id
                    }
                    networkSecurityGroup: {
                        id: nsgAllowSshFromHubBastionInBound.id
                    }
                    privateEndpointNetworkPolicies: 'Disabled'
                    privateLinkServiceNetworkPolicies: 'Disabled'
                }
            }
            {
                name: 'snet-management-acragents'
                properties: {
                    addressPrefix: '10.240.251.0/28'
                    /*routeTable: {
                        id: afRouteTable.id
                    }*/
                    networkSecurityGroup: {
                        id: nsgAcrDockerSubnet.id
                    }
                    privateEndpointNetworkPolicies: 'Disabled'
                    privateLinkServiceNetworkPolicies: 'Disabled'
                }
            }
            {
                name: 'snet-privatelinkendpoints'
                properties: {
                    addressPrefix: '10.240.250.0/28'
                    routeTable: {
                        id: afRouteTable.id
                    }
                    networkSecurityGroup: {
                        id: nsgAksPrivateLinkEndpoint.id
                    }
                    privateEndpointNetworkPolicies: 'Disabled'
                    privateLinkServiceNetworkPolicies: 'Enabled'
                }
            }
        ]
        dhcpOptions: {
            dnsServers: [
                hubFirewall.properties.ipConfigurations[0].properties.privateIPAddress
            ]
        }
    }

    resource aksSystemNodepoolSubnet 'subnets' existing = {
        name: 'snet-cluster-systemnodepool'
    }

    resource aksSystemInScopeNodepoolsSubnet 'subnets' existing = {
        name: 'snet-cluster-inscopenodepools'
    }

    resource aksSystemOutOfScopeNodepoolsSubnet 'subnets' existing = {
        name: 'snet-cluster-outofscopenodepools'
    }

    resource aksManagementOpsSubnet 'subnets' existing = {
        name: 'snet-management-ops'
    }
}

@description('Peer to regional hub.')
resource clusterVNet_virtualNetworkPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-05-01' = {
    name: 'spoke-to-${last(split(hubVnetResourceId, '/'))}'
    parent: clusterVNet
    properties: {
        remoteVirtualNetwork: {
            id: hubVnetResourceId
        }
        allowForwardedTraffic: false
        allowVirtualNetworkAccess: true
        allowGatewayTransit: false
        useRemoteGateways: false
    }
}

resource clusterVNet_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
    name: 'toHub'
    scope: clusterVNet
    properties: {
        workspaceId: hubLaWorkspace.id
        metrics: [
            {
                category: 'AllMetrics'
                enabled: true
            }
        ]
    }
}

module hubsSpokesPeering 'modules/hubsSpokesPeeringDeployment.bicep' = {
    name: 'hub-to-clustetVNet-peering'
    scope: rgHubs
    params: {
        hubNetworkName: last(split(hubVnetResourceId, '/'))
        spokesVNetName: clusterVNet.name
        remoteVirtualNetworkId: clusterVNet.id
    }
}

@description('Enables Azure Container Registry Private Link on vnet.')
resource acrPrivateDnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = {
    name: 'privatelink.azurecr.io'
    location: 'global'
    properties: {}
}

@description('Enables cluster vnet private zone DNS lookup - used by cluster vnet for direct DNS queries (ones not proxied via the hub).')
resource acrPrivateDnsZones_virtualNetworkLink_toCluster 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
    name: 'to_${clusterVNet.name}'
    parent: acrPrivateDnsZones
    location: 'global'
    properties: {
        virtualNetwork: {
            id: clusterVNet.id
        }
        registrationEnabled: false
    }
}

@description('Enabling hub vnet private zone DNS lookup for ACR - used by azure firewall\'s dns proxy.')
resource acrPrivateDnsZones_virtualNetworkLink_toHubVNet 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
    name: 'to_${last(split(hubVnetResourceId, '/'))}'
    parent: acrPrivateDnsZones
    location: 'global'
    properties: {
        virtualNetwork: {
            id: hubVnetResourceId
        }
        registrationEnabled: false
    }
}

@description('Enables AKS Private Link on vnet.')
resource aksPrivateDnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = {
    name: 'privatelink.${location}.azmk8s.io'
    location: 'global'
    properties: {}
}

@description('Enables Azure Key Vault Private Link on cluster vnet.')
resource aksPrivateDnsZones_virtualNetworkLink_toClusterVNet 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
    name: 'to_${last(split(hubVnetResourceId, '/'))}'
    parent: aksPrivateDnsZones
    location: 'global'
    properties: {
        virtualNetwork: {
            id: clusterVNet.id
        }
        registrationEnabled: false
    }
}

@description('Enables Azure Key Vault Private Link support.')
resource akvPrivateDnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = {
    name: 'privatelink.vaultcore.azure.net'
    location: 'global'
    properties: {}
}

@description('Enables Azure Key Vault Private Link on cluster vnet.')
resource akvPrivateDnsZones_virtualNetworkLink_toCluster 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
    name: 'to_${clusterVNet.name}'
    parent: akvPrivateDnsZones
    location: 'global'
    properties: {
        virtualNetwork: {
            id: clusterVNet.id
        }
        registrationEnabled: false
    }
}

@description('Enables hub vnet private zone DNS lookup for ACR - used by azure firewall\'s dns proxy.')
resource akvPrivateDnsZones_virtualNetworkLink_toHubVNet 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
    name: 'to_${last(split(hubVnetResourceId, '/'))}'
    parent: akvPrivateDnsZones
    location: 'global'
    properties: {
        virtualNetwork: {
            id: hubVnetResourceId
        }
        registrationEnabled: false
    }
}

@description('Used as primary entry point for workload. Expected to be assigned to an Azure Application Gateway.')
resource pipPrimaryCluster 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
    name: 'pip-BU0001A0005-00'
    location: location
    sku: {
        name: 'Standard'
    }
    properties: {
        publicIPAllocationMethod: 'Static'
        idleTimeoutInMinutes: 4
        publicIPAddressVersion: 'IPv4'
    }
}

resource networkWatcherResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = if (deployFlowLogResources) {
    scope: subscription()
    name: 'networkWatcherRG'
}

@description('Storage account to store the flow logs')
resource flowlogs_storageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' existing = {
    scope: rgHubs
    name: substring('stnfl${location}${uniqueString(rgHubs.id)}', 0, 24)
}

module flowlogsDeploymentAcrDockerSubnet 'modules/flowlogsDeployment.bicep' = if (deployFlowLogResources) {
    name: 'flowlogs-Deployment-AcrDockerSubnet-NSG'
    scope: networkWatcherResourceGroup
    params: {
      location: location
      targetResourceId: nsgAcrDockerSubnet.id
      laHubId: hubLaWorkspace.id
      flowLogsStorageId: flowlogs_storageAccount.id
    }
}

module flowlogsDeploymentAksDefaultILBSubnet 'modules/flowlogsDeployment.bicep' = if (deployFlowLogResources) {
    name: 'flowlogs-Deployment-AksDefaultILB-Subnet-NSG'
    scope: networkWatcherResourceGroup
    params: {
      location: location
      targetResourceId: nsgAksDefaultILBSubnet.id
      laHubId: hubLaWorkspace.id
      flowLogsStorageId: flowlogs_storageAccount.id
    }
}

module flowlogsDeploymentAppGatewaySubnet 'modules/flowlogsDeployment.bicep' = if (deployFlowLogResources) {
    name: 'flowlogs-Deployment-AppGateway-Subnet-NSG'
    scope: networkWatcherResourceGroup
    params: {
      location: location
      targetResourceId: nsgAppGatewaySubnet.id
      laHubId: hubLaWorkspace.id
      flowLogsStorageId: flowlogs_storageAccount.id
    }
}

module flowlogsDeploymentksInScopeNodepools 'modules/flowlogsDeployment.bicep' = if (deployFlowLogResources) {
    name: 'flowlogs-Deploymentks-InScopeNodepools-NSG'
    scope: networkWatcherResourceGroup
    params: {
      location: location
      targetResourceId: nsgAksInScopeNodepools.id
      laHubId: hubLaWorkspace.id
      flowLogsStorageId: flowlogs_storageAccount.id
    }
}

module flowlogsDeploymentAllowSshFromHubBastionInBound 'modules/flowlogsDeployment.bicep' = if (deployFlowLogResources) {
    name: 'flowlogs-Deployment-AllowSshFromHubBastionInBound-NSG'
    scope: networkWatcherResourceGroup
    params: {
      location: location
      targetResourceId: nsgAllowSshFromHubBastionInBound.id
      laHubId: hubLaWorkspace.id
      flowLogsStorageId: flowlogs_storageAccount.id
    }
}

module flowlogsDeploymentAksOutOfScopeNodepools 'modules/flowlogsDeployment.bicep' = if (deployFlowLogResources) {
    name: 'flowlogs-Deployment-AksOutOfScopeNodepools-NSG'
    scope: networkWatcherResourceGroup
    params: {
      location: location
      targetResourceId: nsgAksOutOfScopeNodepools.id
      laHubId: hubLaWorkspace.id
      flowLogsStorageId: flowlogs_storageAccount.id
    }
}

module flowlogsDeploymentAksPrivateLinkEndpoint 'modules/flowlogsDeployment.bicep' = if (deployFlowLogResources) {
    name: 'flowlogs-Deployment-AksPrivateLinkEndpoint-NSG'
    scope: networkWatcherResourceGroup
    params: {
      location: location
      targetResourceId: nsgAksPrivateLinkEndpoint.id
      laHubId: hubLaWorkspace.id
      flowLogsStorageId: flowlogs_storageAccount.id
    }
}

module flowlogsDeploymentAksSystemNodepools 'modules/flowlogsDeployment.bicep' = if (deployFlowLogResources) {
    name: 'flowlogs-Deployment-AksSystemNodepools-NSG'
    scope: networkWatcherResourceGroup
    params: {
      location: location
      targetResourceId: nsgAksSystemNodepools.id
      laHubId: hubLaWorkspace.id
      flowLogsStorageId: flowlogs_storageAccount.id
    }
}

/*** OUTPUTS ***/

output clusterVnetResourceId string = clusterVNet.id

output jumpboxSubnetResourceId string = clusterVNet::aksManagementOpsSubnet.id

output nodepoolSubnetResourceIds array = [
    clusterVNet::aksSystemNodepoolSubnet
    clusterVNet::aksSystemInScopeNodepoolsSubnet
    clusterVNet::aksSystemOutOfScopeNodepoolsSubnet
]

output appGwPublicIpAddress string = pipPrimaryCluster.properties.ipAddress
