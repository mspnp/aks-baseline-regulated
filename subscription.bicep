targetScope = 'subscription'

/* Required Permissions 
        - Scope: Subscription
          Role: Contributor
          Reason: Creating resource groups, azure policy definations and assignments

       Optional Permissions
        - Scope: Subscription
          Role: Security Admin (or Owner)
          Reason: To enable Microsoft Defender for Kubernetes, Container Registry, and Key Vault.
          Notes: If unable to obtain permissions, you must pass false to the enableMicrosoftDefenderForCloud parameter or have someone else enable these for you.
*/

/*** PARAMETERS ***/

@description('By default Microsoft Defender for Kubernetes Service, Container Registry, and Key Vault are configured to deploy via Azure Policy, use this parameter to disable that.')
param enforceAzureDefenderAutoDeployPolicies bool = true

@description('By default Microsoft Defender for Containers service is enabled; use this parameter to prevent the involved pricings from being enabled. Deploying these requires subscription Owner or Security Admin roles.')
param enableMicrosoftDefenderForCloud bool = true

@description('networkWatcherRG often times already exists in a subscription. Empty string will result in using the default resource location.')
param networkWatcherRGRegion string = ''

/*** VARIABLES ***/

@description('This region is used as the default for all generic resource groups and for any additional deployment resources. No resources are actually deployed to this resource group.')
var deploymentResourceRegion = 'centralus' 

/*** EXISTING RESOURCES ***/

@description('Security Admin Role built-in role.')
resource securityAdminRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
    name: 'fb1c8493-542b-48eb-b624-b4c8fea62acd'
}

/*** RESOURCES ***/

@description('This contains all of our regional hubs. Typically this would be found in your enterprise\'s Connectivity subscription.')
resource rgHubs 'Microsoft.Resources/resourceGroups@2021-04-01' = {
    name: 'rg-enterprise-networking-hubs'
    location: deploymentResourceRegion
}

@description('This contains all of our regional spokes. Typically this would be found in your enterprise\'s Connectivity subscription or in the workload\'s subscription.')
resource rgSpokes 'Microsoft.Resources/resourceGroups@2021-04-01' = {
    name: 'rg-enterprise-networking-spokes'
    location: deploymentResourceRegion
}

@description('This is the resource group for BU001A0005. Typically this would be found in your workload\'s subscription.')
resource rgbu0001a0005 'Microsoft.Resources/resourceGroups@2021-04-01'  = {
    name: 'rg-bu0001a0005'
    location: deploymentResourceRegion
}

@description('This is the resource group for Azure Network Watchers. Most subscriptions already have this.')
resource rgNetworkWatchers 'Microsoft.Resources/resourceGroups@2021-04-01' = {
    name: 'networkWatcherRG'
    location: empty(networkWatcherRGRegion) ? deploymentResourceRegion : networkWatcherRGRegion
}

@description('Microsoft Defender for Containers provides real-time threat protection for containerized environments and generates alerts for suspicious activities.')
resource pdEnableAksDefender 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
    name: guid(subscription().id, 'EnableDefenderForAks')
    properties: {
        displayName: 'Microsoft Defender for Containers is enabled'
        policyType: 'Custom'
        mode: 'All'
        description: 'Microsoft Defender for Containers provides real-time threat protection for containerized environments and generates alerts for suspicious activities.'
        metadata: {
            version: '1.0.0'
            category: 'Microsoft Defender for Cloud'
        }
        policyRule: {
            if: {
                allOf: [
                    {
                        field: 'type'
                        equals: 'Microsoft.Resources/subscriptions'
                    }
                ]
            }
            then: {
                effect: 'deployIfNotExists'
                details: {
                    type: 'Microsoft.Security/pricings'
                    name: 'Containers'
                    deploymentScope: 'subscription'
                    existenceScope: 'subscription'
                    roleDefinitionIds: [
                        securityAdminRole.id
                    ]
                    existenceCondition: {
                        field: 'Microsoft.Security/pricings/pricingTier'
                        equals: 'Standard'
                    }
                    deployment: {
                        location: deploymentResourceRegion
                        properties: {
                            mode: 'incremental'
                            template: {
                                '$schema': 'https://schema.management.azure.com/schemas/2018-05-01/subscriptionDeploymentTemplate.json#'
                                contentVersion: '1.0.0.0'
                                resources: [
                                    {
                                        type: 'Microsoft.Security/pricings'
                                        apiVersion: '2018-06-01'
                                        name: 'Containers'
                                        properties: {
                                            pricingTier: 'Standard'
                                        }
                                    }
                                ]
                            }
                        }
                    }
                }
            }
        }
    }
}

@description('Microsoft Defender for Key Vault provides an additional layer of protection and security intelligence by detecting unusual and potentially harmful attempts to access or exploit key vault accounts.')
resource pdEnableAkvDefender 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
    name: guid(subscription().id, 'EnableDefenderForAkv')
    properties: {
        displayName: 'Microsoft Defender for Key Vault is enabled'
        policyType: 'Custom'
        mode: 'All'
        description: 'Microsoft Defender for Key Vault provides an additional layer of protection and security intelligence by detecting unusual and potentially harmful attempts to access or exploit key vault accounts.'
        metadata: {
            version: '1.0.0'
            category: 'Microsoft Defender for Cloud'
        }
        policyRule: {
            if: {
                allOf: [
                    {
                        field: 'type'
                        equals: 'Microsoft.Resources/subscriptions'
                    }
                ]
            }
            then: {
                effect: 'deployIfNotExists'
                details: {
                    type: 'Microsoft.Security/pricings'
                    name: 'KeyVaults'
                    deploymentScope: 'subscription'
                    existenceScope: 'subscription'
                    roleDefinitionIds: [
                        securityAdminRole.id
                    ]
                    existenceCondition: {
                        field: 'Microsoft.Security/pricings/pricingTier'
                        equals: 'Standard'
                    }
                    deployment: {
                        location: deploymentResourceRegion
                        properties: {
                            mode: 'incremental'
                            template: {
                                '$schema': 'https://schema.management.azure.com/schemas/2018-05-01/subscriptionDeploymentTemplate.json#'
                                contentVersion: '1.0.0.0'
                                resources: [
                                    {
                                        type: 'Microsoft.Security/pricings'
                                        apiVersion: '2018-06-01'
                                        name: 'KeyVaults'
                                        properties: {
                                            pricingTier: 'Standard'
                                        }
                                    }
                                ]
                            }
                        }
                    }
                }
            }
        }
    }
}

@description('Ensures Microsoft Defender is enabled for select resources.')
resource psdEnableDefender 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
    name: guid(subscription().id, 'EnableDefender')
    properties: {
        displayName: 'Enable Microsoft Defender Standard'
        description: 'Ensures Microsoft Defender is enabled for select resources'
        policyType: 'Custom'
        metadata: {
            version: '1.0.0'
            category: 'Microsoft Defender for Cloud'
        }
        policyDefinitions: [
            {
                policyDefinitionId: pdEnableAksDefender.id
            }
            {
                policyDefinitionId: pdEnableAkvDefender.id
            }
        ]
    }
}

@description('Microsoft Defender for Containers should be enabled in the cluster.')
resource pdDenyAksWithoutDefender 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
    name: guid(subscription().id, 'DenyNonDefenderAks')
    properties: {
        description: 'This policy denies the creation of Azure Kubernetes Service cluster that is not protected with Microsoft Defender for Containers.'
        displayName: 'Microsoft Defender for Containers should be enabled in the cluster.'
        policyType: 'Custom'
        mode: 'All'
        metadata: {
            version: '1.0.0'
        }
        policyRule: {
            if: {
                allOf: [
                    {
                        field: 'type'
                        equals: 'Microsoft.ContainerService/managedClusters'
                    }
                    {
                        field: 'Microsoft.ContainerService/managedClusters/securityProfile.azureDefender.enabled'
                        notequals: 'true'
                    }
                ]
            }
            then: {
                effect: 'deny'
            }
        }
    }
}

@description('This policy denies the creation of Azure Kubernetes Service non-private clusters.')
resource pdDenyPublicAks 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
    name: guid(subscription().id, 'DenyPublicAks')
    properties: {
        description: 'This policy denies the creation of Azure Kubernetes Service non-private clusters'
        displayName: 'Public network access on AKS API should be disabled'
        policyType: 'Custom'
        mode: 'All'
        metadata: {
            version: '1.0.0'
        }
        policyRule: {
            if: {
                allOf: [
                    {
                        field: 'type'
                        equals: 'Microsoft.ContainerService/managedClusters'
                    }
                    {
                        field: 'Microsoft.ContainerService/managedClusters/apiServerAccessProfile.enablePrivateCluster'
                        notequals: 'true'
                    }
                ]
            }
            then: {
                effect: 'Deny'
            }
        }
    }
}

@description('This policy denies the creation of Azure Application Gateway without WAF feature.')
resource pdDenyAagWithoutWaf 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
    name: guid(subscription().id, 'DenyAagWithoutWaf')
    properties: {
        description: 'This policy denies the creation of Azure Application Gateway without WAF feature'
        displayName: 'WAF SKU must be enabled on Azure Application Gateway'
        policyType: 'Custom'
        mode: 'All'
        metadata: {
            version: '1.0.0'
        }
        policyRule: {
            if: {
                allOf: [
                    {
                        field: 'type'
                        equals: 'Microsoft.Network/applicationGateways'
                    }
                    {
                        field: 'Microsoft.Network/applicationGateways/sku.name'
                        notequals: 'WAF_v2'
                    }
                ]
            }
            then: {
                effect: 'Deny'
            }
        }
    }
}

@description('This policy denies network interfaces with public IPs to be attached to the identified Virtual Network. Applied at the subscription level, but expected to be limited to a specific vnet.')
resource pdNoPublicIPsForNICsInVnet 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
    name: guid(subscription().id, 'NoPublicIPsForNICsInVnet')
    properties: {
        displayName: 'Virtual Network should not have NICs attached with public IPs'
        description: 'This policy denies network interfaces with public IPs to be attached to the identified Virtual Network. Applied at the subscription level, but expected to be limited to a specific vnet.'
        policyType: 'Custom'
        mode: 'All'
        metadata: {
            version: '1.0.0'
            category: 'Network'
        }
        parameters: {
            vnetResourceId: {
                type: 'String'
                metadata: {
                    displayName: 'Virtual Network'
                    description: 'The Vnet Resource ID that cannot have public IPs'
                    strongType: 'Microsoft.Network/virtualNetworks'
                }
            }
        }
        policyRule: {
            if: {
                anyOf: [
                    {
                        allOf: [
                            {
                                field: 'type'
                                equals: 'Microsoft.Network/networkInterfaces'
                            }
                            {
                                field: 'Microsoft.Network/networkInterfaces/ipConfigurations[*].publicIpAddress.id'
                                like: '*'
                            }
                            {
                                field: 'Microsoft.Network/networkInterfaces/ipConfigurations[*].subnet.id'
                                contains: '[parameters(\'vnetResourceId\')]'
                            }
                        ]
                    }
                    {
                        allOf: [
                            {
                                field: 'type'
                                equals: 'Microsoft.Compute/virtualMachineScaleSets'
                            }
                            {
                                field: 'Microsoft.Compute/virtualMachineScaleSets/virtualMachineProfile.networkProfile.networkInterfaceConfigurations[*].ipConfigurations[*].publicIPAddressConfiguration.name'
                                like: '*'
                            }
                            {
                                field: 'Microsoft.Compute/virtualMachineScaleSets/virtualMachineProfile.networkProfile.networkInterfaceConfigurations[*].ipConfigurations[*].subnet.id'
                                contains: '[parameters(\'vnetResourceId\')]'
                            }
                        ]
                    }
                ]
            }
            then: {
                effect: 'deny'
            }
        }
    }
}

@description('This policy denies the creation VM Scale Sets which are are configured with any public IPs.')
resource pdNoPublicIPsForVMScaleSets 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
    name: guid(subscription().id, 'NoPublicIPsForVMScaleSets')
    properties: {
        displayName: 'VM Scale Sets should not have public IPs'
        description: 'This policy denies the creation VM Scale Sets which are are configured with any public IPs.'
        policyType: 'Custom'
        mode: 'All'
        metadata: {
            version: '1.0.0'
            category: 'Compute'
        }
        parameters: {}
        policyRule: {
            if: {
                allOf: [
                    {
                        field: 'type'
                        equals: 'Microsoft.Compute/virtualMachineScaleSets'
                    }
                    {
                        field: 'Microsoft.Compute/virtualMachineScaleSets/virtualMachineProfile.networkProfile.networkInterfaceConfigurations[*].ipConfigurations[*].publicIPAddressConfiguration.name'
                        like: '*'
                    }
                ]
            }
            then: {
                effect: 'deny'
            }
        }
    }
}

@description('Hubs policies deployment')
module hubsPoliciesDeployment 'modules/hubsPoliciesDeployment.bicep' = {
    name: 'Apply-${rgHubs.name}-Policies'
    scope: rgHubs
}

@description('Spokes policies deployment')
module spokesPoliciesDeployment 'modules/spokesPoliciesDeployment.bicep' = {
    name: 'Apply-${rgSpokes.name}-Policies'
    scope: rgSpokes
}

@description('Network watcher\'s policies deployment')
module networkWatchersPoliciesDeployment 'modules/networkWatchersPoliciesDeployment.bicep' = {
    name: 'Apply-${rgNetworkWatchers.name}-Policies'
    scope: rgNetworkWatchers
}

@description('Workload\'s policies deployment')
module workloadPoliciesDeployment 'modules/workloadPoliciesDeployment.bicep' = {
    dependsOn: [
        pdDenyPublicAks
        pdDenyAksWithoutDefender
        pdNoPublicIPsForVMScaleSets
        pdDenyAagWithoutWaf
    ]
    name: 'Apply-${rgbu0001a0005.name}-Policies'
    scope: rgbu0001a0005
}

@description('Ensures that Microsoft Defender for Kuberentes Service, Container Service, and Key Vault are enabled. - Policy Assignment')
module defenderPolicyDeployment 'modules/subscriptionPolicyAssignment.bicep' = {
    name: 'Apply-EnableDefender-Policy'
    scope: subscription()
    params: {
        location: deploymentResourceRegion
        polcyAssignmentMetadata: {
            version: '1.0.0'
            category: 'Microsoft Defender for Cloud'
        }
        policyDefinitionSetName: psdEnableDefender.name
        policyAssignmentDescription: 'Ensures that Microsoft Defender for Kuberentes Service, Container Service, and Key Vault are enabled.'
        enforcementMode: enforceAzureDefenderAutoDeployPolicies ? 'Default' : 'DoNotEnforce'
    }
}

@description('Enable Microsoft Defender Standard for Key Vault. Requires Owner or Security Admin role.')
resource enableKeyVaultspricing 'Microsoft.Security/pricings@2018-06-01' = if (enableMicrosoftDefenderForCloud) {
    name: 'KeyVaults'
    properties: {
        pricingTier: 'Standard'
    }
}

@description('Enable Microsoft Defender Standard for Container Registry. Deprecated, please move to Defender for Containers. Requires Owner or Security Admin role.')
resource enableContainerRegistry 'Microsoft.Security/pricings@2018-06-01' = if (enableMicrosoftDefenderForCloud) {
    name: 'ContainerRegistry'
    properties: {
        pricingTier: 'Standard'
    }
}

@description('Enable Microsoft Defender for Kubernetes Service. Deprecated, please move to Defender for Containers. Requires Owner or Security Admin role.')
resource enableKubernetesService 'Microsoft.Security/pricings@2018-06-01' = if (enableMicrosoftDefenderForCloud) {
    name: 'KubernetesService'
    properties: {
        pricingTier: 'Standard'
    }
}

@description('Enable Microsoft Defender Standard for Azure Resource Manager. Requires Owner or Security Admin role.')
resource enableArm 'Microsoft.Security/pricings@2018-06-01' = if (enableMicrosoftDefenderForCloud) {
    name: 'Arm'
    properties: {
        pricingTier: 'Standard' // Isn't included in the Azure Policy applications above.
    }
}

@description('Enable Microsoft Defender Standard for Azure DNS. Requires Owner or Security Admin role.')
resource enableDns 'Microsoft.Security/pricings@2018-06-01' = if (enableMicrosoftDefenderForCloud) {
    name: 'Dns'
    properties: {
        pricingTier: 'Standard' // Isn't included in the Azure Policy applications above.
    }
}
