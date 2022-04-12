targetScope = 'resourceGroup'

/*** RESOURCES ***/

@description('Allowed Resources Policy applied to the hubs RG to only allow select networking and observation resources.')
module allowedResourcespolicyAssignment 'allowedResourcespolicyAssignment.bicep' = {
    name: 'Hubs-allowedResourcespolicyAssignment'
    scope: resourceGroup()
}

module DenyPublicAksPolicyAssignment 'DenyPublicAksPolicyAssignment.bicep' = {
    name: 'Workload-DenyPublicAksPolicyAssignment'
    scope: resourceGroup()
}

@description('Deny the creation of Azure Kubernetes Service cluster that is not protected with Microsoft Defender for Containers.')
module DenyAksWithoutDefenderPolicyAssignment 'DenyAksWithoutDefenderPolicyAssignment.bicep' = {
    name: 'Workload-DenyAksWithoutDefenderPolicyAssignment'
    scope: resourceGroup()
}

@description('Applying the \'No Public IPs on VMSS\' policy to the appliction resource group.')
module NoPublicIPsForVMScaleSetsPolicyAssignment 'NoPublicIPsForVMScaleSetsPolicyAssignment.bicep' = {
    name: 'Workload-NoPublicIPsForVMScaleSetsPolicyAssignment'
    scope: resourceGroup()
}

@description('Deny AKS clusters that do not have Azure Policy enabled in the appliction resource group.')
module DenyAksWithoutPolicyPolicyAssignment 'DenyAksWithoutPolicyPolicyAssignment.bicep' = {
    name: 'Workload-DenyAksWithoutPolicyPolicyAssignment'
    scope: resourceGroup()
}

@description('Deny public AKS clusters policy applied to the appliction resource group.')
module DenyAagWithoutWafPolicyAssignment 'DenyAagWithoutWafPolicyAssignment.bicep' = {
    name: 'Workload-DenyAagWithoutWafPolicyAssignment'
    scope: resourceGroup()
}

@description('Deny AKS clusters without RBAC policy applied to the appliction resource group.')
module DenyAksWithoutRbacPolicyAssignment 'DenyAksWithoutRbacPolicyAssignment.bicep' = {
    name: 'Workload-DenyAksWithoutRbacPolicyAssignment'
    scope: resourceGroup()
}

@description('Deny AKS clusters on old version policy applied to the appliction resource group.')
module DenyOldAksPolicyAssignment 'DenyOldAksPolicyAssignment.bicep' = {
    name: 'Workload-DenyOldAksPolicyAssignment'
    scope: resourceGroup()
}

@description('Applying the \'Customer-Managed Disk Encryption\' policy to the resource group.')
module CustomerManagedEncryptionPolicyAssignment 'CustomerManagedEncryptionPolicyAssignment.bicep' = {
    name: 'Workload-CustomerManagedEncryptionPolicyAssignment'
    scope: resourceGroup()
}

@description('Applying the \'Encryption at Host\' policy to the resource group.')
module EncryptionAtHostPolicyAssignment 'EncryptionAtHostPolicyAssignment.bicep' = {
    name: 'Workload-EncryptionAtHostPolicyAssignment'
    scope: resourceGroup()
}
