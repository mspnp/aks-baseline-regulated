targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('allowedResources Policy Definition Id')
param allowedResourcesPolicyDefinitionId string

@description('DenyPublicAks Policy Definition Id')
param DenyPublicAksPolicyDefinitionId string

@description('networkWatcherShouldBeEnabled Policy Definition Id')
param DenyAksWithoutDefenderPolicyDefinitionId string

@description('NoPublicIPsForVMScaleSets Policy Definition Id')
param NoPublicIPsForVMScaleSetsPolicyDefinitionId string

@description('DenyAksWithoutPolicy Policy Definition Id')
param DenyAksWithoutPolicyPolicyDefinitionId string

@description('DenyAagWithoutWafPolicy Policy Definition Id')
param DenyAagWithoutWafPolicyDefinitionId string

@description('DenyAksWithoutRbac Policy Definition Id')
param DenyAksWithoutRbacPolicyDefinitionId string

@description('DenyOldAks Policy Definition Id')
param DenyOldAksPolicyDefinitionId string

@description('CustomerManagedEncryption Policy Definition Id')
param CustomerManagedEncryptionPolicyDefinitionId string

@description('EncryptionAtHost Policy Definition Id')
param EncryptionAtHostPolicyDefinitionId string


@description('The hubs resource group')
param rgWorkload string

/*** RESOURCES ***/

@description('Allowed Resources Policy applied to the hubs RG to only allow select networking and observation resources.')
module allowedResourcespolicyAssignment 'policyAssignmentDeploymentRG.bicep' = {
    name: 'Hubs-allowedResourcespolicyAssignment'
    scope: resourceGroup(rgWorkload)
    params: {
        name: guid(allowedResourcesPolicyDefinitionId, rgWorkload)
        displayName: trim(take('[${rgWorkload}] ${reference(allowedResourcesPolicyDefinitionId, '2020-09-01').displayName}', 125))
        policyAssignmentDescription: 'List of supported resources for our workload resource group'
        policyDefinitionId: allowedResourcesPolicyDefinitionId
        parameters: {
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

@description('Deny public AKS clusters policy applied to the workload resource group.')
module DenyPublicAksPolicyAssignment 'policyAssignmentDeploymentRG.bicep' = {
    name: 'Workload-DenyPublicAksPolicyAssignment'
    scope: resourceGroup(rgWorkload)
    params: {
        name: guid(DenyPublicAksPolicyDefinitionId, rgWorkload)
        displayName: trim(take('[${rgWorkload}] ${reference(DenyPublicAksPolicyDefinitionId, '2020-09-01').displayName}', 125))
        policyAssignmentDescription: 'Only support private AKS clusters, deny any other.'
        policyDefinitionId: DenyPublicAksPolicyDefinitionId
        parameters: {}
    }
}

@description('Deny the creation of Azure Kubernetes Service cluster that is not protected with Microsoft Defender for Containers.')
module DenyAksWithoutDefenderPolicyAssignment 'policyAssignmentDeploymentRG.bicep' = {
    name: 'Workload-DenyAksWithoutDefenderPolicyAssignment'
    scope: resourceGroup(rgWorkload)
    params: {
        name: guid(DenyAksWithoutDefenderPolicyDefinitionId, rgWorkload)
        displayName: trim(take('[${rgWorkload}] ${reference(DenyAksWithoutDefenderPolicyDefinitionId, '2020-09-01').displayName}', 125))
        policyAssignmentDescription: 'Microsoft Defender for Containers should be enabled in the cluster.'
        policyDefinitionId: DenyAksWithoutDefenderPolicyDefinitionId
        parameters: {}
    }
}

@description('Applying the \'No Public IPs on VMSS\' policy to the appliction resource group.')
module NoPublicIPsForVMScaleSetsPolicyAssignment 'policyAssignmentDeploymentRG.bicep' = {
    name: 'Workload-NoPublicIPsForVMScaleSetsPolicyAssignment'
    scope: resourceGroup(rgWorkload)
    params: {
        name: guid(NoPublicIPsForVMScaleSetsPolicyDefinitionId, rgWorkload)
        displayName: trim(take('[${rgWorkload}] ${reference(NoPublicIPsForVMScaleSetsPolicyDefinitionId, '2020-09-01').displayName}', 125))
        policyDefinitionId: NoPublicIPsForVMScaleSetsPolicyDefinitionId
        parameters: {}
    }
}

@description('Deny AKS clusters that do not have Azure Policy enabled in the appliction resource group.')
module DenyAksWithoutPolicyPolicyAssignment 'policyAssignmentDeploymentRG.bicep' = {
    name: 'Workload-DenyAksWithoutPolicyPolicyAssignment'
    scope: resourceGroup(rgWorkload)
    params: {
        name: guid(DenyAksWithoutPolicyPolicyDefinitionId, rgWorkload)
        displayName: trim(take('[${rgWorkload}] ${reference(DenyAksWithoutPolicyPolicyDefinitionId, '2020-09-01').displayName}', 125))
        policyAssignmentDescription: 'Only support AKS clusters with Azure Policy enabled, deny any other.'
        policyDefinitionId: DenyAksWithoutPolicyPolicyDefinitionId
        parameters: {}
    }
}

@description('Deny public AKS clusters policy applied to the appliction resource group.')
module DenyAagWithoutWafPolicyAssignment 'policyAssignmentDeploymentRG.bicep' = {
    name: 'Workload-DenyAagWithoutWafPolicyAssignment'
    scope: resourceGroup(rgWorkload)
    params: {
        name: guid(DenyAagWithoutWafPolicyDefinitionId, rgWorkload)
        displayName: trim(take('[${rgWorkload}] ${reference(DenyAagWithoutWafPolicyDefinitionId, '2020-09-01').displayName}', 125))
        policyAssignmentDescription: 'Only allow Azure Application Gateway SKU with WAF support.'
        policyDefinitionId: DenyAagWithoutWafPolicyDefinitionId
        parameters: {}
    }
}

@description('Deny AKS clusters without RBAC policy applied to the appliction resource group.')
module DenyAksWithoutRbacPolicyAssignment 'policyAssignmentDeploymentRG.bicep' = {
    name: 'Workload-DenyAksWithoutRbacPolicyAssignment'
    scope: resourceGroup(rgWorkload)
    params: {
        name: guid(DenyAksWithoutRbacPolicyDefinitionId, rgWorkload)
        displayName: trim(take('[${rgWorkload}] ${reference(DenyAksWithoutRbacPolicyDefinitionId, '2020-09-01').displayName}', 125))
        policyAssignmentDescription: 'Only allow AKS with RBAC support enabled.'
        policyDefinitionId: DenyAksWithoutRbacPolicyDefinitionId
        parameters: {}
    }
}

@description('Deny AKS clusters on old version policy applied to the appliction resource group.')
module DenyOldAksPolicyAssignment 'policyAssignmentDeploymentRG.bicep' = {
    name: 'Workload-DenyOldAksPolicyAssignment'
    scope: resourceGroup(rgWorkload)
    params: {
        name: guid(DenyOldAksPolicyDefinitionId, rgWorkload)
        displayName: trim(take('[${rgWorkload}] ${reference(DenyOldAksPolicyDefinitionId, '2020-09-01').displayName}', 125))
        policyAssignmentDescription: 'Disallow older AKS versions.'
        policyDefinitionId: DenyOldAksPolicyDefinitionId
        parameters: {}
    }
}

@description('Applying the \'Customer-Managed Disk Encryption\' policy to the resource group.')
module CustomerManagedEncryptionPolicyAssignment 'policyAssignmentDeploymentRG.bicep' = {
    name: 'Workload-CustomerManagedEncryptionPolicyAssignment'
    scope: resourceGroup(rgWorkload)
    params: {
        name: guid(CustomerManagedEncryptionPolicyDefinitionId, rgWorkload)
        displayName: trim(take('[${rgWorkload}] ${reference(CustomerManagedEncryptionPolicyDefinitionId, '2020-09-01').displayName}', 125))
        policyDefinitionId: CustomerManagedEncryptionPolicyDefinitionId
        parameters: {}
    }
}

@description('Applying the \'Encryption at Host\' policy to the resource group.')
module EncryptionAtHostPolicyAssignment 'policyAssignmentDeploymentRG.bicep' = {
    name: 'Workload-EncryptionAtHostPolicyAssignment'
    scope: resourceGroup(rgWorkload)
    params: {
        name: guid(EncryptionAtHostPolicyDefinitionId, rgWorkload)
        displayName: trim(take('[${rgWorkload}] ${reference(EncryptionAtHostPolicyDefinitionId, '2020-09-01').displayName}', 125))
        policyDefinitionId: EncryptionAtHostPolicyDefinitionId
        parameters: {}
    }
}


