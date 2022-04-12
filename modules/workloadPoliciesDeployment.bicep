targetScope = 'resourceGroup'

/*** RESOURCES ***/

@description('Allowed Resources Policy applied to the hubs RG to only allow select networking and observation resources.')
module allowedResourcespolicyAssignment 'policyAssignmentDeploymentRG.bicep' = {
    name: 'Hubs-allowedResourcespolicyAssignment'
    scope: resourceGroup()
    params: {
        name: guid('/providers/Microsoft.Authorization/policyDefinitions/a08ec900-254a-4555-9bf5-e42af04b5c5c', resourceGroup().name)
        displayName: trim(take('[${resourceGroup().name}] ${reference('/providers/Microsoft.Authorization/policyDefinitions/a08ec900-254a-4555-9bf5-e42af04b5c5c', '2020-09-01').displayName}', 125))
        policyAssignmentDescription: 'List of supported resources for our workload resource group'
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/a08ec900-254a-4555-9bf5-e42af04b5c5c'
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




module DenyPublicAksPolicyAssignment 'policyAssignmentDeploymentRG.bicep' = {
    name: 'Workload-DenyPublicAksPolicyAssignment'
    scope: resourceGroup()
    params: {
        name: guid(guid(subscription().id, 'DenyPublicAks'), resourceGroup().name)
        displayName: trim(take('[${resourceGroup().name}] ${reference(subscriptionResourceId('Microsoft.Authorization/policyDefinitions', guid(subscription().id, 'DenyPublicAks')), '2020-09-01').displayName}', 125))
        policyAssignmentDescription: 'Only support private AKS clusters, deny any other.'
        policyDefinitionId: subscriptionResourceId('Microsoft.Authorization/policyDefinitions', guid(subscription().id, 'DenyPublicAks'))
        parameters: {}
    }
}

@description('Deny the creation of Azure Kubernetes Service cluster that is not protected with Microsoft Defender for Containers.')
module DenyAksWithoutDefenderPolicyAssignment 'policyAssignmentDeploymentRG.bicep' = {
    name: 'Workload-DenyAksWithoutDefenderPolicyAssignment'
    scope: resourceGroup()
    params: {
        name: guid(guid(subscription().id, 'DenyNonDefenderAks'), resourceGroup().name)
        displayName: trim(take('[${resourceGroup().name}] ${reference(subscriptionResourceId('Microsoft.Authorization/policyDefinitions', guid(subscription().id, 'DenyNonDefenderAks')), '2020-09-01').displayName}', 125))
        policyAssignmentDescription: 'Microsoft Defender for Containers should be enabled in the cluster.'
        policyDefinitionId: subscriptionResourceId('Microsoft.Authorization/policyDefinitions', guid(subscription().id, 'DenyNonDefenderAks'))
        parameters: {}
    }
}

@description('Applying the \'No Public IPs on VMSS\' policy to the appliction resource group.')
module NoPublicIPsForVMScaleSetsPolicyAssignment 'policyAssignmentDeploymentRG.bicep' = {
    name: 'Workload-NoPublicIPsForVMScaleSetsPolicyAssignment'
    scope: resourceGroup()
    params: {
        name: guid(guid(subscription().id, 'NoPublicIPsForVMScaleSets'), resourceGroup().name)
        displayName: trim(take('[${resourceGroup().name}] ${reference(subscriptionResourceId('Microsoft.Authorization/policyDefinitions', guid(subscription().id, 'NoPublicIPsForVMScaleSets')), '2020-09-01').displayName}', 125))
        policyDefinitionId: subscriptionResourceId('Microsoft.Authorization/policyDefinitions', guid(subscription().id, 'NoPublicIPsForVMScaleSets'))
        parameters: {}
    }
}

@description('Deny AKS clusters that do not have Azure Policy enabled in the appliction resource group.')
module DenyAksWithoutPolicyPolicyAssignment 'policyAssignmentDeploymentRG.bicep' = {
    name: 'Workload-DenyAksWithoutPolicyPolicyAssignment'
    scope: resourceGroup()
    params: {
        name: guid(guid(subscription().id, 'DenyAksWithoutPolicy'), resourceGroup().name)
        displayName: trim(take('[${resourceGroup().name}] ${reference(subscriptionResourceId('Microsoft.Authorization/policyDefinitions', guid(subscription().id, 'DenyAksWithoutPolicy')), '2020-09-01').displayName}', 125))
        policyAssignmentDescription: 'Only support AKS clusters with Azure Policy enabled, deny any other.'
        policyDefinitionId: subscriptionResourceId('Microsoft.Authorization/policyDefinitions', guid(subscription().id, 'DenyAksWithoutPolicy'))
        parameters: {}
    }
}

@description('Deny public AKS clusters policy applied to the appliction resource group.')
module DenyAagWithoutWafPolicyAssignment 'policyAssignmentDeploymentRG.bicep' = {
    name: 'Workload-DenyAagWithoutWafPolicyAssignment'
    scope: resourceGroup()
    params: {
        name: guid(guid(subscription().id, 'DenyAagWithoutWaf'), resourceGroup().name)
        displayName: trim(take('[${resourceGroup().name}] ${reference(subscriptionResourceId('Microsoft.Authorization/policyDefinitions', guid(subscription().id, 'DenyAagWithoutWaf')), '2020-09-01').displayName}', 125))
        policyAssignmentDescription: 'Only allow Azure Application Gateway SKU with WAF support.'
        policyDefinitionId: subscriptionResourceId('Microsoft.Authorization/policyDefinitions', guid(subscription().id, 'DenyAagWithoutWaf'))
        parameters: {}
    }
}

@description('Deny AKS clusters without RBAC policy applied to the appliction resource group.')
module DenyAksWithoutRbacPolicyAssignment 'policyAssignmentDeploymentRG.bicep' = {
    name: 'Workload-DenyAksWithoutRbacPolicyAssignment'
    scope: resourceGroup()
    params: {
        name: guid(guid(subscription().id, 'DenyAksWithoutRbac'), resourceGroup().name)
        displayName: trim(take('[${resourceGroup().name}] ${reference(subscriptionResourceId('Microsoft.Authorization/policyDefinitions', guid(subscription().id, 'DenyAksWithoutRbac')), '2020-09-01').displayName}', 125))
        policyAssignmentDescription: 'Only allow AKS with RBAC support enabled.'
        policyDefinitionId: subscriptionResourceId('Microsoft.Authorization/policyDefinitions', guid(subscription().id, 'DenyAksWithoutRbac'))
        parameters: {}
    }
}

@description('Deny AKS clusters on old version policy applied to the appliction resource group.')
module DenyOldAksPolicyAssignment 'policyAssignmentDeploymentRG.bicep' = {
    name: 'Workload-DenyOldAksPolicyAssignment'
    scope: resourceGroup()
    params: {
        name: guid(guid(subscription().id, 'DenyOldAksVersions'), resourceGroup().name)
        displayName: trim(take('[${resourceGroup().name}] ${reference(subscriptionResourceId('Microsoft.Authorization/policyDefinitions', guid(subscription().id, 'DenyOldAksVersions')), '2020-09-01').displayName}', 125))
        policyAssignmentDescription: 'Disallow older AKS versions.'
        policyDefinitionId: subscriptionResourceId('Microsoft.Authorization/policyDefinitions', guid(subscription().id, 'DenyOldAksVersions'))
        parameters: {}
    }
}

@description('Applying the \'Customer-Managed Disk Encryption\' policy to the resource group.')
module CustomerManagedEncryptionPolicyAssignment 'policyAssignmentDeploymentRG.bicep' = {
    name: 'Workload-CustomerManagedEncryptionPolicyAssignment'
    scope: resourceGroup()
    params: {
        name: guid(guid(subscription().id, 'CustomerManagedEncryption'), resourceGroup().name)
        displayName: trim(take('[${resourceGroup().name}] ${reference(subscriptionResourceId('Microsoft.Authorization/policyDefinitions', guid(subscription().id, 'CustomerManagedEncryption')), '2020-09-01').displayName}', 125))
        policyDefinitionId: subscriptionResourceId('Microsoft.Authorization/policyDefinitions', guid(subscription().id, 'CustomerManagedEncryption'))
        parameters: {}
    }
}

@description('Applying the \'Encryption at Host\' policy to the resource group.')
module EncryptionAtHostPolicyAssignment 'policyAssignmentDeploymentRG.bicep' = {
    name: 'Workload-EncryptionAtHostPolicyAssignment'
    scope: resourceGroup()
    params: {
        name: guid(guid(subscription().id, 'EncryptionAtHost'), resourceGroup().name)
        displayName: trim(take('[${resourceGroup().name}] ${reference(subscriptionResourceId('Microsoft.Authorization/policyDefinitions', guid(subscription().id, 'EncryptionAtHost')), '2020-09-01').displayName}', 125))
        policyDefinitionId: subscriptionResourceId('Microsoft.Authorization/policyDefinitions', guid(subscription().id, 'EncryptionAtHost'))
        parameters: {}
    }
}
