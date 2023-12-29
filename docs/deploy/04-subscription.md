# Prepare Cluster Subscription

In the prior step, you've set up a Microsoft Entra tenant to fullfil your [cluster's control plane (Kubernetes Cluster API) authorization](./03-auth.md) needs for this reference implementation deployment. Now you'll prepare the subscription which host this infrastructure. This includes creating the resource groups and applying some high-level Azure Policies to govern our deployments.

## Subscription and resource group topology

This reference implementation is split across several resource groups in a single subscription. This is to replicate the fact that many organizations will split certain responsibilities into specialized subscriptions (such as regional hubs in a *Connectivity* subscription and workloads in landing zone subscriptions). We expect you to explore this reference implementation within a single subscription, but when you implement this cluster at your organization, you will need to take what you've learned here and apply it to your expected subscription and resource group topology; such as those [offered by the Cloud Adoption Framework](https://learn.microsoft.com/azure/cloud-adoption-framework/decision-guides/subscriptions/). This single subscription, multiple resource group model is for simplicity of demonstration purposes only.

## Expected results

### Resource groups created

The following four resource groups will be created in these steps.

| Name                            | Purpose                                   |
|---------------------------------|-------------------------------------------|
| rg-enterprise-networking-hubs   | Contains all of your organization's regional hubs. A regional hub resources in this implementation include the hub Virtual Network, egress firewall, Azure Bastion, and Log Analytics for network logging. They may also contain your VPN Gateways, which are not addressed in this implementation. |
| rg-enterprise-networking-spokes | Contains all of your organization's regional spokes and related networking resources. All spokes will peer with their regional hub and subnets will egress through the regional firewall in the hub. |
| rg-bu0001a0005                  | Contains the regulated cluster resources. |
| networkWatcherRG                | Contains regional Network Watchers. *(Most subscriptions already have this.)* |

Both Azure Kubernetes Service and Azure Image Builder Service use a concept of a dynamically-created *infrastructure* resource group. So in addition to the four resource groups mentioned above, as you follow these instructions, you'll end up with six resource groups; two of which are automatically created and their lifecycle tied to their owning service. You will not see these two infrastructure resource groups get created until later in the walkthrough when their owning service is created.

### Azure Policy applied

To help govern our resources, there are policies we apply over the scope of these resource groups. These policies will also be created in the following steps.

| Azure Policy Name                    | Scope                           | Purpose                                                                                           |
|--------------------------------|---------------------------------|---------------------------------------------------------------------------------------------------|
| Enable Microsoft Defender for Cloud Standard | Subscription                | Ensures that Microsoft Defender for Containers, DNS, Key Vault, and Resource Manager are always enabled. |
| Allowed resource types         | rg-enterprise-networking-hubs   | Restricts the hub resource group to just relevant networking resources.                           |
| Virtual Network must have Network Watcher | rg-enterprise-networking-hubs   | Audit Azure Policy that will trigger if a network is deployed to a region that doesn't have a Network Watcher. *(This is only created if your subscription doesn't already have Network Watchers in place.)* |
| Allowed resource types         | rg-enterprise-networking-spokes | Restricts the spokes resource group to just relevant networking resources.                        |
| Virtual Network must have Network Watcher | rg-enterprise-networking-spokes | Audit Azure Policy that will trigger if a network is deployed to a region that doesn't have a Network Watcher. *(This is only created if your subscription doesn't already have Network Watchers in place.)* |
| Allowed resource types         | rg-bu0001a0005                  | Restricts the workload resource group to just resources necessary for this specific architecture. |
| Allowed resource types         | networkWatcherRG                | Restricts the Network Watcher resource group to just Network Watcher resources. *(Audit only mode to prevent conflict with any existing Azure Policy that manages this common resource group.)* |
| No public AKS clusters         | rg-bu0001a0005                  | Restricts the creation of AKS clusters to only those with private Kubernetes API server.   |
| No out-of-date AKS clusters    | rg-bu0001a0005                  | Restricts the creation of AKS clusters to only recent versions.                            |
| No AKS clusters without RBAC   | rg-bu0001a0005                  | Restricts the creation of AKS clusters to only those that are Microsoft Entra RBAC enabled.       |
| No AKS clusters without Azure Policy | rg-bu0001a0005            | Restricts the creation of AKS clusters to only those that have the Azure Policy Add-on enabled.   |
| No AKS clusters without BYOK OS & Data Disk Encryption | rg-bu0001a0005  | Restricts the creation of AKS clusters to only those that have customer-managed disk encryption enabled. (*This is in audit only mode, as not all customers may wish to do this.*) |
| No AKS clusters without encryption-at-host | rg-bu0001a0005      | Restricts the creation of AKS clusters to only those that have the Encryption-At-Host feature enabled. (*This is in audit only mode, as not all customers may wish to do this.*) |
| No AKS clusters without Microsoft Defender for Containers | rg-bu0001a0005                | Restricts the creation of AKS clusters to only those that have the Microsoft Defender for Containers feature enabled. |
| No App Gateways without WAF    | rg-bu0001a0005                  | Restricts the creation of Azure Application Gateway to only the WAF SKU. |
| No VMSS with public IPs        | rg-bu0001a0005                  | Only VMSS that do not have public IPs can be created in this resource group. |

For this reference implementation, our Azure Policies applied to these resource groups are maximally restrictive on what resource types are allowed to be deployed and what features they must have enabled/disable. If you alter the deployment by adding additional Azure resources, you may need to update the *Allowed resource types* policy for that resource group to accommodate your modification.

This is not an exhaustive list of Azure Policies that you can create or assign, and instead an example of the types of policies you should consider having in place. Policies like these help prevent a misconfiguration of a service that would expose you to unexpected compliance concerns. Let the Azure control plane guard against configurations that are untenable for your compliance requirements as an added safeguard. While we deploy policies at the subscription and resource group scope, your organization may also utilize management groups. We've found it's best to also ensure your target subscription and target resource groups have "scope-local" policies specific to their needs; so it doesn't take a dependency on a higher order Azure Policy existing or not -- even if that leads to a duplication of Azure Policy.

> :notebook: For more information, see [Azure Architecture Center guidance for PCI-DSS 3.2.1 Requirement 2.2.4 in AKS](https://learn.microsoft.com/azure/architecture/reference-architectures/containers/aks-pci/aks-pci-network#requirement-224) and [Azure Policy considerations](https://learn.microsoft.com/azure/architecture/reference-architectures/containers/aks-pci/aks-pci-ra-code-assets#azure-policy-considerations).

Also, depending on your workload subscription scope, some of the policies applied above may be better suited at the subscription level (like no public AKS clusters). Since we don't assume you're coming to this walkthrough with a dedicated subscription, we've scoped the restrictions to only those resource groups we ask you to create. Apply your policies where it makes the most sense to do so in your final implementation.

### Microsoft Defender for Cloud activated

As mentioned in the Azure Policy section above, we enable the following Microsoft Defender for Cloud's services.

- [Microsoft Defender for Containers](https://learn.microsoft.com/azure/defender-for-cloud/defender-for-containers-introduction)
- [Microsoft Defender for Key Vault](https://learn.microsoft.com/azure/defender-for-cloud/defender-for-key-vault-introduction)
- [Microsoft Defender for DNS](https://learn.microsoft.com/azure/defender-for-cloud/defender-for-dns-introduction)
- [Microsoft Defender for Resource Manager](https://learn.microsoft.com/azure/defender-for-cloud/defender-for-resource-manager-introduction)

Not only do we enable them in the following steps by default, but also set up an Azure Policy that ensures they stay enabled.

## Steps

1. Login into the Azure subscription that you'll be deploying into. 🛑

   ```bash
   az login -t <Replace-With-Azure-Subscription-TenantId>
   ```

1. Verify you're on the correct subscription.

   ```bash
   az account show -o table

   # If not, select the correct subscription
   # az account set -s <subscription name or id>

   TENANTID_AZURERBAC=$(az account show --query tenantId -o tsv)
   ```

1. Check for a pre-existing resource group with the name `networkWatcherRG`.

   ```bash
   NETWORK_WATCHER_RG_REGION=$(az group list --query "[?name=='networkWatcherRG' || name=='NetworkWatcherRG'].location" -o tsv)
   ```

   If your subscription is managed in such a way that Azure Network Watcher resources are found in a resource group other than the Azure default of `networkWatcherRG` or they do not use the Azure default `NetworkWatcher_<region>` naming convention, you will need to adjust the various ARM templates to compensate. Network Watchers are singletons (per region) in subscriptions, and organizations often manage them (and Flow Logs) via Azure Policy. This walkthrough assumes default naming conventions as set by Azure's [automatic deployment feature of Network Watchers](https://learn.microsoft.com/azure/network-watcher/network-watcher-create#network-watcher-is-automatically-enabled).

   If at any time during the deployment you get an error stating "**resource 'NetworkWatcher_\<region>' not found**", you will need to skip flow log creation by passing `false` to that ARM template's `deployFlowLogResources` parameter or you can manually create the required Network Watcher with that name.

1. Perform subscription-level deployment.

   This will deploy the resource groups, Azure Policies, and Microsoft Defender for Cloud configuration all as identified above.

   ```bash
   # [This may take up to six minutes to run.]
   az deployment sub create -f subscription.bicep -l centralus -p networkWatcherRGRegion="${NETWORK_WATCHER_RG_REGION}"
   ```

   If you do not have permissions on your subscription to enable Microsoft Defender for Cloud (which requires the Azure RBAC role of *Subscription Owner* or *Security Admin*), then instead execute the following variation of the same command. This will not enable Microsoft Defender for Cloud services nor will Azure Policy attempt to enable the same (the Azure Policy will still be created, but in audit-only mode). Your final implementation should be to a subscription with these security services activated.

   ```bash
   # [This may take up to five minutes to run.]
   az deployment sub create -f subscription.bicep -l centralus -p enableMicrosoftDefenderForCloud=false enforceAzureDefenderAutoDeployPolicies=false networkWatcherRGRegion="${NETWORK_WATCHER_RG_REGION}"
   ```

## Azure Security Benchmark

It is recommended that your Azure *subscription* have the **Azure Security Benchmark** Azure Policy initiative applied. We could not deploy it in bicep above, as we don't want to overwrite anything already existing in your subscription. This Azure Policy can only be applied once for Microsoft Defender for Cloud to detect it properly, and if we deployed a version above, you might inadvertently break existing Azure Policy configuration on your subscription. If you have the ability to apply it without any negative impact on other resources your subscription, you can do so by doing the following.

> :notebook: For more information, see [Azure Architecture Center guidance for PCI-DSS 3.2.1 Requirement 2.2 in AKS](https://learn.microsoft.com/azure/architecture/reference-architectures/containers/aks-pci/aks-pci-network#requirement-22).

### Steps

1. Open the [**Regulatory Compliance** screen in Microsoft Defender for Cloud](https://portal.azure.com/#blade/Microsoft_Azure_Security/SecurityMenuBlade/22)
1. Click on **Manage compliance policies**
1. Expand the tree, and click on your subscription
1. Navigate to **Security policy** blade since you'll want to ensure the **Azure Security Benchmark** and all relevant standards (such as **PCI DSS 3.2.1**) are **Enabled** under **Industry & regulatory standards**
1. The **Regulatory Compliance** dashboard in Microsoft Defender for Cloud might take an hour or two to reflect any modifications you've made.

**None of the above is required for this walkthrough**, but we want to ensure you're aware of these subscription-level policies and how you can enable them for your final implementation. All subscriptions containing PCI workloads should have the **PCI DSS 3.2.1** Industry and regulatory standards reports enabled, which *requires* that the **Azure Security Benchmark** is applied as the default policy.

## Other Azure Policies

Consider evaluating additional Azure Policies to help guard your subscription from undesirable resource deployments. Here are some to consider.

- [PCI DSS v4 initiative](https://github.com/Azure/azure-policy/blob/master/built-in-policies/policySetDefinitions/Regulatory%20Compliance/PCI_DSS_V4.0.json)
- Allowed locations
- Allowed locations for resource groups
- External accounts with read permissions should be removed from your subscription
- External accounts with write permissions should be removed from your subscription
- External accounts with owner permissions should be removed from your subscription
- Network interfaces should not have public IPs

Like the Azure Security Benchmark, we'd like to apply these, and similar, in this walkthrough; but we acknowledge that they might be disruptive if you are deploying this walkthrough to a subscription with other existing resources. Take the time to review the [built-in Azure Policies](https://portal.azure.com/#blade/Microsoft_Azure_Policy/PolicyMenuBlade/Definitions) and the [ability to create your own](https://learn.microsoft.com/azure/governance/policy/tutorials/create-and-manage), and craft policies that will help keep you within regulatory compliance from an Azure Resource location and features perspective.

## Accessing compliance documentation

A summary of all of [Microsoft and Azure's compliance offerings are available](https://learn.microsoft.com/compliance/regulatory/offering-home). If you're looking for compliance reports (AOC, Shared Responsibility Matrix), you can access them via the Azure Portal. Your regulatory requirements may require you to have a copy of these documents available.

### Steps

1. Open the [**Regulatory Compliance** screen in Microsoft Defender for Cloud](https://portal.azure.com/#blade/Microsoft_Azure_Security/SecurityMenuBlade/22)
1. Click on **Audit reports**
1. Select your interest (such as **PCI**)
1. Download and read relevant documents (such as **PCI DSS 3.2.1 - Azure Shared Responsibility Matrix** or **Azure PCI DSS 3.2.1 AOC Package**)

### Next step

:arrow_forward: [Deploy the regional hub network](./05-networking-hub.md).
