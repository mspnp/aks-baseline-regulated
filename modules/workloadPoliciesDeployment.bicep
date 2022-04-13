targetScope = 'resourceGroup'

/*** RESOURCES ***/

@description('Only support the a list of resources for our workload resource group - Policy assignment')
module allowedResourcespolicyAssignment 'resourceGroupPolicyAssignment.bicep' = {
    name: 'Hubs-allowedResourcespolicyAssignment'
    scope: resourceGroup()
    params: {
        builtIn: true
        policyDefinitionName: 'a08ec900-254a-4555-9bf5-e42af04b5c5c'
        policyAssignmentDescription: 'List of supported resources for our workload resource group'
        policyAssignmentParameters: {
            listOfResourceTypesAllowed: {
                value: [
                    'Microsoft.Compute/images'
                    'Microsoft.Compute/virtualMachineScaleSets'
                    'Microsoft.ContainerRegistry/registries'
                    'Microsoft.ContainerRegistry/registries/agentPools'
                    'Microsoft.ContainerRegistry/registries/replications'
                    'Microsoft.ContainerService/managedClusters'
                    'Microsoft.Insights/activityLogAlerts'
                    'Microsoft.Insights/metricAlerts'
                    'Microsoft.Insights/scheduledQueryRules'
                    'Microsoft.Insights/workbooks'
                    'Microsoft.KeyVault/vaults'
                    'Microsoft.ManagedIdentity/userAssignedIdentities'
                    'Microsoft.Network/applicationGateways'
                    'Microsoft.Network/networkInterfaces'
                    'Microsoft.Network/networkSecurityGroups'
                    'Microsoft.Network/networkSecurityGroups/securityRules'
                    'Microsoft.Network/privateDnsZones'
                    'Microsoft.Network/privateDnsZones/virtualNetworkLinks'
                    'Microsoft.Network/privateEndpoints'
                    'Microsoft.OperationalInsights/workspaces'
                    'Microsoft.OperationsManagement/solutions'
                    'Microsoft.VirtualMachineImages/imageTemplates'
                ]
            }
        }
    }
}

resource pdDenyPublicAks 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
    name: guid(subscription().id, 'DenyPublicAks')
    scope: subscription()
}

@description('Only support private AKS clusters, deny any other. - Policy Assignment')
module DenyPublicAksPolicyAssignment 'resourceGroupPolicyAssignment.bicep' = {
    name: 'Workload-DenyPublicAksPolicyAssignment'
    scope: resourceGroup()
    params: {
        builtIn: false
        policyDefinitionName: pdDenyPublicAks.name
        policyAssignmentDescription: 'Only support private AKS clusters, deny any other.'
    }
}

resource pdDenyNonDefenderAks 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
    name: guid(subscription().id, 'DenyNonDefenderAks')
    scope: subscription()
}

@description('Microsoft Defender for Containers should be enabled in the cluster - Policy Assignment')
module DenyAksWithoutDefenderPolicyAssignment 'resourceGroupPolicyAssignment.bicep' = {
    name: 'Workload-DenyAksWithoutDefenderPolicyAssignment'
    scope: resourceGroup()
    params: {
        builtIn: false
        policyDefinitionName: pdDenyNonDefenderAks.name
        policyAssignmentDescription: 'Microsoft Defender for Containers should be enabled in the cluster.'
    }
}

resource pdNoPublicIPsForVMScaleSets 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
    name: guid(subscription().id, 'NoPublicIPsForVMScaleSets')
    scope: subscription()
}

@description('\'No Public IPs on VMSS\' policy applied to the workload resource group. - Policy Assignment')
module NoPublicIPsForVMScaleSetsPolicyAssignment 'resourceGroupPolicyAssignment.bicep' = {
    name: 'Workload-NoPublicIPsForVMScaleSetsPolicyAssignment'
    scope: resourceGroup()
    params: {
        builtIn: false
        policyDefinitionName: pdNoPublicIPsForVMScaleSets.name
    }
}

@description('Only support AKS clusters with Azure Policy enabled, deny any other. - Policy Assignment')
module DenyAksWithoutPolicyPolicyAssignment 'resourceGroupPolicyAssignment.bicep' = {
    name: 'Workload-DenyAksWithoutPolicyPolicyAssignment'
    scope: resourceGroup()
    params: {
        builtIn: true
        policyDefinitionName: '0a15ec92-a229-4763-bb14-0ea34a568f8d'
        policyAssignmentDescription: 'Only support AKS clusters with Azure Policy enabled, deny any other.'
    }
}

resource pdDenyAagWithoutWaf 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
    name: guid(subscription().id, 'DenyAagWithoutWaf')
    scope: subscription()
}

@description('Only allow Azure Application Gateway SKU with WAF support. - Policy assignment')
module DenyAagWithoutWafPolicyAssignment 'resourceGroupPolicyAssignment.bicep' = {
    name: 'Workload-DenyAagWithoutWafPolicyAssignment'
    scope: resourceGroup()
    params: {
        builtIn: false
        policyDefinitionName: pdDenyAagWithoutWaf.name
        policyAssignmentDescription: 'Only allow Azure Application Gateway SKU with WAF support.'
    }
}

@description('Deny AKS clusters without RBAC policy applied to the appliction resource group. - Policy assignment')
module DenyAksWithoutRbacPolicyAssignment 'resourceGroupPolicyAssignment.bicep' = {
    name: 'Workload-DenyAksWithoutRbacPolicyAssignment'
    scope: resourceGroup()
    params: {
        builtIn: true
        policyDefinitionName: 'ac4a19c2-fa67-49b4-8ae5-0b2e78c49457'
        policyAssignmentDescription: 'Only allow AKS with RBAC support enabled.'
    }
}

@description('Deny AKS clusters on old version policy applied to the appliction resource group. - Policy Assignment')
module DenyOldAksPolicyAssignment 'resourceGroupPolicyAssignment.bicep' = {
    name: 'Workload-DenyOldAksPolicyAssignment'
    scope: resourceGroup()
    params: {
        builtIn: true
        policyDefinitionName: 'fb893a29-21bb-418c-a157-e99480ec364c'
        policyAssignmentDescription: 'Disallow older AKS versions.'
    }
}

@description('\'Customer-Managed Disk Encryption\' applied to resource group - Policy Assignment.')
module CustomerManagedEncryptionPolicyAssignment 'resourceGroupPolicyAssignment.bicep' = {
    name: 'Workload-CustomerManagedEncryptionPolicyAssignment'
    scope: resourceGroup()
    params: {
        builtIn: true
        policyDefinitionName: '7d7be79c-23ba-4033-84dd-45e2a5ccdd67'
    }
}

@description('\'Encryption at Host\' policy applied to the resource group - Policy Assignment.')
module EncryptionAtHostPolicyAssignment 'resourceGroupPolicyAssignment.bicep' = {
    name: 'Workload-EncryptionAtHostPolicyAssignment'
    scope: resourceGroup()
    params: {
        builtIn: true
        policyDefinitionName: '41425d9f-d1a5-499a-9932-f8ed8453932c'
    }
}
