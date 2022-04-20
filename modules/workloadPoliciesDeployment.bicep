targetScope = 'resourceGroup'

/*** VARIABLES ***/

@description('Role-Based Access Control (RBAC) should be used on Kubernetes Services - Policy definition.')
var denyAksWithoutRbacPolicyDefinitionName = 'ac4a19c2-fa67-49b4-8ae5-0b2e78c49457'

@description('Only support the a list of resources for our workload resource group - Policy definition.')
var allowedResourcespolicyAssignmentName = 'a08ec900-254a-4555-9bf5-e42af04b5c5c'

@description('Azure Policy Add-on for Kubernetes service (AKS) should be installed and enabled on your clusters - Policy definition')
var DenyAksWithoutPolicyPolicyDefinitionName = '0a15ec92-a229-4763-bb14-0ea34a568f8d'

@description('Kubernetes Services should be upgraded to a non-vulnerable Kubernetes version - Policy definition')
var DenyOldAksPolicyDefinitionName = 'fb893a29-21bb-418c-a157-e99480ec364c'

@description('Kubernetes Services should be upgraded to a non-vulnerable Kubernetes version - Policy definition')
var CustomerManagedEncryptionPolicyDefinitionName = '7d7be79c-23ba-4033-84dd-45e2a5ccdd67'

@description('Temp disks and cache for agent node pools in Azure Kubernetes Service clusters should be encrypted at host - Policy definition')
var EncryptionAtHostPolicyDefinitionName = '41425d9f-d1a5-499a-9932-f8ed8453932c'

/*** EXISTING RESOURCES ***/

resource pdDenyPublicAks 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
    name: guid(subscription().id, 'DenyPublicAks')
    scope: subscription()
}


resource pdDenyNonDefenderAks 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
    name: guid(subscription().id, 'DenyNonDefenderAks')
    scope: subscription()
}

resource pdNoPublicIPsForVMScaleSets 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
    name: guid(subscription().id, 'NoPublicIPsForVMScaleSets')
    scope: subscription()
}

resource pdDenyAagWithoutWaf 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
    name: guid(subscription().id, 'DenyAagWithoutWaf')
    scope: subscription()
}

/*** RESOURCES ***/

@description('Only support the a list of resources for our workload resource group - Policy assignment')
module allowedResourcespolicyAssignment 'resourceGroupPolicyAssignment.bicep' = {
    name: 'Hubs-allowedResourcespolicyAssignment'
    scope: resourceGroup()
    params: {
        builtIn: true
        policyDefinitionName: allowedResourcespolicyAssignmentName
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

@description('\'No Public IPs on VMSS\' policy applied to the workload resource group. - Policy Assignment')
module NoPublicIPsForVMScaleSetsPolicyAssignment 'resourceGroupPolicyAssignment.bicep' = {
    name: 'Workload-NoPublicIPsForVMScaleSetsPolicyAssignment'
    scope: resourceGroup()
    params: {
        builtIn: false
        policyDefinitionName: pdNoPublicIPsForVMScaleSets.name
        policyAssignmentDescription: '\'No Public IPs on VMSS\' policy applied to the workload resource group.'
    }
}

@description('Only support AKS clusters with Azure Policy enabled, deny any other. - Policy Assignment')
module DenyAksWithoutPolicyPolicyAssignment 'resourceGroupPolicyAssignment.bicep' = {
    name: 'Workload-DenyAksWithoutPolicyPolicyAssignment'
    scope: resourceGroup()
    params: {
        builtIn: true
        policyDefinitionName: DenyAksWithoutPolicyPolicyDefinitionName
        policyAssignmentDescription: 'Only support AKS clusters with Azure Policy enabled, deny any other.'
    }
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
        policyDefinitionName: denyAksWithoutRbacPolicyDefinitionName
        policyAssignmentDescription: 'Only allow AKS with RBAC support enabled.'
    }
}

@description('Deny AKS clusters on old version policy applied to the appliction resource group. - Policy Assignment')
module DenyOldAksPolicyAssignment 'resourceGroupPolicyAssignment.bicep' = {
    name: 'Workload-DenyOldAksPolicyAssignment'
    scope: resourceGroup()
    params: {
        builtIn: true
        policyDefinitionName: DenyOldAksPolicyDefinitionName
        policyAssignmentDescription: 'Disallow older AKS versions.'
    }
}

@description('\'Customer-Managed Disk Encryption\' applied to resource group - Policy Assignment.')
module CustomerManagedEncryptionPolicyAssignment 'resourceGroupPolicyAssignment.bicep' = {
    name: 'Workload-CustomerManagedEncryptionPolicyAssignment'
    scope: resourceGroup()
    params: {
        builtIn: true
        policyDefinitionName: CustomerManagedEncryptionPolicyDefinitionName
        policyAssignmentDescription: '\'Customer-Managed Disk Encryption\' applied to resource group'
    }
}

@description('Temp disks and cache for agent node pools in Azure Kubernetes Service clusters should be encrypted at host - Policy Assignment.')
module EncryptionAtHostPolicyAssignment 'resourceGroupPolicyAssignment.bicep' = {
    name: 'Workload-EncryptionAtHostPolicyAssignment'
    scope: resourceGroup()
    params: {
        builtIn: true
        policyDefinitionName: EncryptionAtHostPolicyDefinitionName
        policyAssignmentDescription: 'Temp disks and cache for agent node pools in Azure Kubernetes Service clusters should be encrypted at host'
    }
}
