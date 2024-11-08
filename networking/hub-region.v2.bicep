targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('Subnet resource Ids for all AKS clusters nodepools in all attached spokes to allow necessary outbound traffic through the firewall')
param nodepoolSubnetResourceIds array

@description('Subnet resource Id for the AKS image builder subnet')
@minLength(79)
param aksImageBuilderSubnetResourceId string

@description('Subnet resource Id for the AKS jumpbox subnet')
@minLength(79)
param aksJumpboxSubnetResourceId string

@description('A /24 to contain the regional firewall, management, and gateway subnet')
@minLength(10)
@maxLength(18)
param hubVnetAddressSpace string = '10.200.0.0/24'

@description('A /26 under the VNet Address Space for the regional Azure Firewall')
@minLength(10)
@maxLength(18)
param azureFirewallSubnetAddressSpace string = '10.200.0.0/26'

@description('A /27 under the VNet Address Space for our regional On-Prem Gateway')
@minLength(10)
@maxLength(18)
param azureGatewaySubnetAddressSpace string = '10.200.0.64/27'

@description('A /27 under the VNet Address Space for regional Azure Bastion')
@minLength(10)
@maxLength(18)
param azureBastionSubnetAddressSpace string = '10.200.0.96/27'

@description('Flow Logs are enabled by default, if for some reason they cause conflicts with flow log policies already in place in your subscription, you can disable them by passing "false" to this parameter.')
param deployFlowLogResources bool = true

/*** VARIABLES ***/

@description('The hub\'s regional affinity. All resources tied to this hub will also be homed in this region. The network team maintains an approved regional list which is a subset of regions with Availability Zone support. Defaults to the resource group\'s location for higher availability.')
var location = resourceGroup().location

/*** EXISTING RESOURCES ***/

@description('The resource group name containing virtual network in which Azure Image Builder will drop the compute into to perform the image build.')
resource rgSpokes 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  scope: subscription()
  name: split(aksImageBuilderSubnetResourceId, '/')[4]
}

@description('AKS Spoke Virtual Network BU0001A0005-00')
resource aksImageBuilderVnet 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  scope: rgSpokes
  name: split(aksImageBuilderSubnetResourceId, '/')[8]
}

@description('AKS ImageBuilder subnet')
resource aksImageBuilderSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' existing = {
  parent: aksImageBuilderVnet
  name: last(split(aksImageBuilderSubnetResourceId, '/'))
}

@description('AKS Spoke Virtual Network BU0001A0005-01')
resource aksJumpboxVnet 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  scope: rgSpokes
  name: split(aksJumpboxSubnetResourceId, '/')[8]
}

@description('AKS Jumpbox subnet')
resource aksJumpboxSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' existing = {
  parent: aksJumpboxVnet
  name: last(split(aksJumpboxSubnetResourceId, '/'))
}

@description('NetworkWatcher ResourceGroup; it contains regional Network Watchers')
resource networkWatcherResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = if (deployFlowLogResources) {
  scope: subscription()
  name: 'networkWatcherRG'
}

/*** RESOURCES ***/

@description('This Log Analytics workspace stores logs from the regional hub network, its spokes, and bastion. Log analytics is a regional resource, as such there will be one workspace per hub (region)')
resource laHub 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: 'la-hub-${location}-${uniqueString(resourceGroup().id, 'vnet-${location}-hub')}'
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

@description('Enables Azure Sentinal integration.')
var laHubSolutionName = 'SecurityInsights(${laHub.name})'
resource laHubSolution 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: laHubSolutionName
  location: location
  plan: {
    name: laHubSolutionName
    promotionCode: ''
    product: 'OMSGallery/SecurityInsights'
    publisher: 'Microsoft'
  }
  properties: {
    workspaceResourceId: laHub.id
  }
}

@description('Wraps the AzureBastion subnet in this regional hub. Source: https://learn.microsoft.com/azure/bastion/bastion-nsg')
resource nsgBastionSubnet 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: 'nsg-${location}-bastion'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowWebExperienceInbound'
        properties: {
          description: 'Allow our users in. Update this to be as restrictive as possible.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowControlPlaneInbound'
        properties: {
          description: 'Service Requirement. Allow control plane access. Regional Tag not yet supported.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHealthProbesInbound'
        properties: {
          description: 'Service Requirement. Allow Health Probes.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowBastionHostToHostInbound'
        properties: {
          description: 'Service Requirement. Allow Required Host to Host Communication.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 130
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          description: 'No further inbound traffic allowed.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 1000
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowSshToVnetOutbound'
        properties: {
          description: 'Allow SSH out to the virtual network'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '22'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowRdpToVnetOutbound'
        properties: {
          description: 'Allow RDP out to the virtual network'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '3389'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowControlPlaneOutbound'
        properties: {
          description: 'Required for control plane outbound. Regional prefix not yet supported'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '443'
          destinationAddressPrefix: 'AzureCloud'
          access: 'Allow'
          priority: 120
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowBastionHostToHostOutbound'
        properties: {
          description: 'Service Requirement. Allow Required Host to Host Communication.'
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 130
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowBastionCertificateValidationOutbound'
        properties: {
          description: 'Service Requirement. Allow Required Session and Certificate Validation.'
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '80'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 140
          direction: 'Outbound'
        }
      }
      {
        name: 'DenyAllOutbound'
        properties: {
          description: 'No further outbound traffic allowed.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 1000
          direction: 'Outbound'
        }
      }
    ]
  }
}

resource nsgBastionSubnet_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: nsgBastionSubnet
  properties: {
    workspaceId: laHub.id
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

@description('The regional hub network')
resource vnetHub 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: 'vnet-${location}-hub'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        hubVnetAddressSpace
      ]
    }
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: azureFirewallSubnetAddressSpace
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: azureGatewaySubnetAddressSpace
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: azureBastionSubnetAddressSpace
          networkSecurityGroup: {
            id: nsgBastionSubnet.id
          }
        }
      }
    ]
  }

  resource azureFirewallSubnet 'subnets' existing = {
    name: 'AzureFirewallSubnet'
  }

  resource azureBastionSubnet 'subnets' existing = {
    name: 'AzureBastionSubnet'
  }
}

resource vnetHub_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: vnetHub
  properties: {
    workspaceId: laHub.id
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

@description('Allocate three public IP addresses to the firewall')
var numFirewallIpAddressesToAssign = 3
resource pipsAzureFirewall 'Microsoft.Network/publicIPAddresses@2021-05-01' = [for i in range(0, numFirewallIpAddressesToAssign): {
  name: 'pip-fw-${location}-${padLeft(i, 2, '0')}'
  location: location
  sku: {
    name: 'Standard'
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    publicIPAddressVersion: 'IPv4'
  }
}]

@description('The public IP for the regional hub\'s Azure Bastion service.')
resource pipAzureBastion 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: 'pip-ab-${location}'
  location: location
  sku: {
    name: 'Standard'
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    publicIPAddressVersion: 'IPv4'
  }
}

@description('This regional hub\'s Azure Bastion service.')
resource azureBastion 'Microsoft.Network/bastionHosts@2021-05-01' = {
  name: 'ab-${location}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'hub-subnet'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnetHub::azureBastionSubnet.id
          }
          publicIPAddress: {
            id: pipAzureBastion.id
          }
        }
      }
    ]
  }
}

resource azureBastion_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: azureBastion
  properties: {
    workspaceId: laHub.id
    logs: [
      {
        category: 'BastionAuditLogs'
        enabled: true
      }
    ]
  }
}

@description('Storage account to store the flow logs')
resource flowlogs_storageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: substring('stnfl${location}${uniqueString(resourceGroup().id)}', 0, 24)
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
    }
  }

  resource blobStorage 'blobServices' existing = {
    name: 'default'
  }
}

resource flowlogs_storageAccount_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: flowlogs_storageAccount
  properties: {
    workspaceId: laHub.id
    logs: []
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}

@description('This holds IP addresses of known AKS Jumpbox image building subnets in attached spokes.')
resource imageBuilder_ipgroup 'Microsoft.Network/ipGroups@2021-05-01' = {
  name: 'ipg-${location}-AksJumpboxImageBuilders'
  location: location
  properties: {
    ipAddresses: [
      aksImageBuilderSubnet.properties.addressPrefix
    ]
  }
}

@description('This holds IP addresses of known AKS Jumpboxs in attached spokes.')
resource aksJumpbox_ipgroup 'Microsoft.Network/ipGroups@2021-05-01' = {
  name: 'ipg-${location}-AksJumpboxes'
  location: location
  properties: {
    ipAddresses: [
      aksJumpboxSubnet.properties.addressPrefix
    ]
  }
}

@description('This holds IP addresses of known nodepool subnets in attached spokes.')
resource aks_ipgroup 'Microsoft.Network/ipGroups@2021-05-01' = {
  name: 'ipg-${location}-AksNodepools'
  location: location
  properties: {
    ipAddresses: [for nodepoolSubnetResourceId in nodepoolSubnetResourceIds: '${reference(nodepoolSubnetResourceId, '2020-05-01').addressPrefix}']
  }
}

resource region_flowlog_storageAccount_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'default'
  scope: flowlogs_storageAccount::blobStorage
  properties: {
    workspaceId: laHub.id
    logs: [
      {
        category: 'StorageRead'
        enabled: true
      }
      {
        category: 'StorageWrite'
        enabled: true
      }
      {
        category: 'StorageDelete'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}

@description('This is the regional Azure Firewall that all regional spoke networks can egress through.')
resource hubFirewall 'Microsoft.Network/azureFirewalls@2021-05-01' = {
  name: 'fw-${location}'
  location: location
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    additionalProperties: {
      'Network.DNS.EnableProxy': 'true'
    }
    sku: {
      tier: 'Premium'
      name: 'AZFW_VNet'
    }
    threatIntelMode: 'Deny'
    ipConfigurations: [for i in range(0, numFirewallIpAddressesToAssign): {
      name: pipsAzureFirewall[i].name
      properties: {
        subnet: (0 == i) ? {
          id: vnetHub::azureFirewallSubnet.id
        } : null
        publicIPAddress: {
          id: pipsAzureFirewall[i].id
        }
      }
    }]
    natRuleCollections: []
    networkRuleCollections: [
      {
        name: 'allow-ntp'
        properties: {
          action: {
            type: 'Allow'
          }
          priority: 100
          rules: [
            {
              name: 'ntp'
              description: 'Network Time Protocol (NTP) time synchronization for image builder VMs and jumpboxes.'
              sourceIpGroups: [
                imageBuilder_ipgroup.id
                aksJumpbox_ipgroup.id
              ]
              protocols: [
                'UDP'
              ]
              destinationPorts: [
                '123'
              ]
              destinationFqdns: [
                'ntp.ubuntu.com'
              ]
            }
          ]
        }
      }
    ]
    applicationRuleCollections: [
      {
        name: 'AKS-Global-Requirements'
        properties: {
          action: {
            type: 'Allow'
          }
          priority: 200
          rules: [
            {
              name: 'runtime'
              description: 'This covers all runtime requirements for AKS (sans addons). If you wish to use a more restricted set of values than what this provides, see: https://learn.microsoft.com/azure/firewall/protect-azure-kubernetes-service and https://learn.microsoft.com/azure/aks/limit-egress-traffic#required-outbound-network-rules-and-fqdns-for-aks-clusters and remove this entry'
              sourceIpGroups: [
                aks_ipgroup.id
              ]
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              fqdnTags: [
                'AzureKubernetesService'
              ]
            }
            {
              name: 'azure-monitor-addon'
              description: 'All required for Azure Monitor for containers per https://learn.microsoft.com/azure/aks/limit-egress-traffic#azure-monitor-for-containers and Managed Prometheus (data collection endpoint) - Optionally you can restrict the ods and oms wildcards to JUST your cluster\'s log analytics instances.'
              sourceIpGroups: [
                aks_ipgroup.id
              ]
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                '*.ods.opinsights.azure.com'
                '*.oms.opinsights.azure.com'
                '${location}.monitoring.azure.com'
                '*.handler.control.monitor.azure.com'
                '*.metrics.ingest.monitor.azure.com'
              ]
            }
            {
              name: 'azure-policy-addon'
              #disable-next-line no-hardcoded-env-urls
              description: 'All required for Azure Policy per https://learn.microsoft.com/azure/aks/limit-egress-traffic#azure-policy. If not using the AzureKubernetesService fqdnTag, you must also add gov-prod-policy-data.trafficmanager.net, raw.githubusercontent.com, and dc.services.visualstudio.com'
              sourceIpGroups: [
                aks_ipgroup.id
              ]
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                #disable-next-line no-hardcoded-env-urls
                'data.policy.core.windows.net'
                #disable-next-line no-hardcoded-env-urls
                'store.policy.core.windows.net'
              ]
            }
          ]
        }
      }
      {
        name: 'Flux-Requirements'
        properties: {
          action: {
            type: 'Allow'
          }
          priority: 300
          rules: [
            {
              name: 'flux-to-github'
              description: 'Supports pulling GitOps configuration from GitHub.'
              sourceIpGroups: [
                aks_ipgroup.id
              ]
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                'github.com'
                'api.github.com'
              ]
            }
            {
              name: 'flux-extension-runtime-requirements'
              description: 'Supports required communication for the Flux v2 extension operate and contains allowances for our applications deployed to the cluster.'
              sourceIpGroups: [
                aks_ipgroup.id
              ]
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                '${location}.dp.kubernetesconfiguration.azure.com'
                'mcr.microsoft.com'
                '${split(environment().resourceManager, '/')[2]}' // Prevent the linter from getting upset at management.azure.com - https://github.com/Azure/bicep/issues/3080
                '${split(environment().authentication.loginEndpoint, '/')[2]}' // Prevent the linter from getting upset at login.microsoftonline.com
                '*.blob.${environment().suffixes.storage}' // required for the extension installer to download the helm chart install flux. This storage account is not predictable, but does look like eusreplstore196 for example.
                'azurearcfork8s.azurecr.io' // required for a few of the images installed by the extension.
              ]
            }
          ]
        }
      }
      {
        name: 'AKSImageBuilder-Requirements'
        properties: {
          action: {
            type: 'Allow'
          }
          priority: 400
          rules: [
            {
              name: 'to-azuremanagement'
              description: 'This for AIB VMs to communicate with Azure management API.'
              sourceIpGroups: [
                imageBuilder_ipgroup.id
              ]
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                #disable-next-line no-hardcoded-env-urls
                'management.azure.com'
              ]
            }
            {
              name: 'to-blobstorage'
              description: 'This is required as the Proxy VM and Packer VM both read and write from transient storage accounts (no ability to know what storage accounts before the process starts.)'
              sourceIpGroups: [
                imageBuilder_ipgroup.id
              ]
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                #disable-next-line no-hardcoded-env-urls
                '*.blob.core.windows.net'
              ]
            }
            {
              name: 'apt-get'
              description: 'This is required as the Packer VM performs a package upgrade. [Step performed in the referenced jump box building process. Not needed if your jump box building process doesn\'t do this.]'
              sourceIpGroups: [
                imageBuilder_ipgroup.id
              ]
              protocols: [
                {
                  protocolType: 'Http'
                  port: 80
                }
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                'azure.archive.ubuntu.com'
                'packages.microsoft.com'
                'archive.ubuntu.com'
                'security.ubuntu.com'
              ]
            }
            {
              name: 'install-azcli'
              description: 'This is required as the Packer VM needs to install Azure CLI. [Step performed in the referenced jump box building process. Not needed if your jump box building process doesn\'t do this.]'
              sourceIpGroups: [
                imageBuilder_ipgroup.id
              ]
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                'aka.ms'
                #disable-next-line no-hardcoded-env-urls
                'azurecliextensionsync.blob.core.windows.net'
                #disable-next-line no-hardcoded-env-urls
                'azurecliprod.blob.core.windows.net'
              ]
            }
            {
              name: 'install-k8scli'
              description: 'This is required as the Packer VM needs to install k8s cli tooling. [Step performed in the referenced jump box building process. Not needed if your jump box building process doesn\'t do this.]'
              sourceIpGroups: [
                imageBuilder_ipgroup.id
              ]
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                'objects.githubusercontent.com'
                'storage.googleapis.com'
                'api.github.com'
                'github-releases.githubusercontent.com'
                'github.com'
              ]
            }
            {
              name: 'install-helm'
              description: 'This is required as the Packer VM needs to install helm cli. [Step performed in the referenced jump box building process. Not needed if your jump box building process doesn\'t do this.]'
              sourceIpGroups: [
                imageBuilder_ipgroup.id
              ]
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                'raw.githubusercontent.com'
                'get.helm.sh'
                'github-releases.githubusercontent.com'
              ]
            }
            {
              name: 'install-open-service-mesh'
              description: 'This is required as the Packer VMs needs to install open service mesh cli. [Step performed in the referenced jump box building process. Not needed if your jump box building process doesn\'t do this.]'
              sourceIpGroups: [
                imageBuilder_ipgroup.id
              ]
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                'github.com'
                'github-releases.githubusercontent.com'
              ]
            }
            {
              name: 'install-terraform'
              description: 'This is required as the Packer VMs needs to install HashiCorp Terraform cli. [Step performed in the referenced jump box building process. Not needed if your jump box building process doesn\'t do this.]'
              sourceIpGroups: [
                imageBuilder_ipgroup.id
              ]
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                'releases.hashicorp.com'
              ]
            }
          ]
        }
      }
      {
        name: 'aks-jumpbox'
        properties: {
          action: {
            type: 'Allow'
          }
          priority: 450
          rules: [
            {
              name: 'az-login'
              description: 'Allow jumpboxes to perform az login.'
              sourceIpGroups: [
                aksJumpbox_ipgroup.id
              ]
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                #disable-next-line no-hardcoded-env-urls
                'login.microsoftonline.com'
              ]
            }
            {
              name: 'az-management-api'
              description: 'Allow jumpboxes to communicate with Azure management APIs.'
              sourceIpGroups: [
                aksJumpbox_ipgroup.id
              ]
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                #disable-next-line no-hardcoded-env-urls
                'management.azure.com'
              ]
            }
            {
              name: 'az-cli-extensions'
              description: 'Allow jumpboxes query az cli status and download extensions'
              sourceIpGroups: [
                aksJumpbox_ipgroup.id
              ]
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                'aka.ms'
                #disable-next-line no-hardcoded-env-urls
                'azurecliprod.blob.core.windows.net'
                #disable-next-line no-hardcoded-env-urls
                'azcliextensionsync.blob.core.windows.net'
              ]
            }
            {
              name: 'github'
              description: 'Allow pulling things down from GitHub. [Only a requirement of this walkthrough because we deploy some manifests that you clone from your repo.]'
              sourceIpGroups: [
                aksJumpbox_ipgroup.id
              ]
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                'github.com'
                '*.github.io'
                'raw.githubusercontent.com'
              ]
            }
            {
              name: 'azure-monitor-addon'
              description: 'Required for Azure Monitor Extension on Jumpbox.'
              sourceIpGroups: [
                aksJumpbox_ipgroup.id
              ]
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                '*.ods.opinsights.azure.com'
                '*.oms.opinsights.azure.com'
                '${location}.monitoring.azure.com'
                '*.agentsvc.azure-automation.net'
              ]
            }
          ]
        }
      }
      {
        name: 'Falco-Requirements'
        properties: {
          action: {
            type: 'Allow'
          }
          priority: 500
          rules: [
            {
              name: 'flux-to-flux-modules'
              description: 'Supports downloading pre-built modules from Falco.'
              sourceIpGroups: [
                aks_ipgroup.id
              ]
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                'download.falco.org'
                'falco.org'
                'falcosecurity.github.io'
                'ghcr.io'
                'pkg-containers.githubusercontent.com'
                'tuf-repo-cdn.sigstore.dev'
              ]
            }
          ]
        }
      }
    ]
  }
}

resource hubFirewall_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: hubFirewall
  properties: {
    workspaceId: laHub.id
    logs: [
      {
        categoryGroup: 'allLogs'
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

@description('Flow Logs deployment')
module regionalFlowlogsDeployment 'modules/flowlogsDeployment.bicep' = if (deployFlowLogResources) {
  name: 'connect-hub-regional-flowlogs'
  scope: networkWatcherResourceGroup
  params: {
    location: location
    targetResourceId: nsgBastionSubnet.id
    laHubId: laHub.id
    flowLogsStorageId: flowlogs_storageAccount.id
  }
}

/*** OUTPUTS ***/

output hubVnetId string = vnetHub.id
output storageAccountName string = flowlogs_storageAccount.name
