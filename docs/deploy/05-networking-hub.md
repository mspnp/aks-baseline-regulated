# Deploy the Regional Hub Network

Now that your subscription has your [Azure Policies and target resource-groups in place](./04-subscription.md), we'll continue by deploying the regional hub which will be the confluent egress point for all traffic in connected spokes.

## Networking in this architecture

Egressing your spoke traffic through a hub network (following the hub-spoke model), is a critical component of this AKS architecture. Your organization's networking team will likely have a specific strategy already in place for this; such as a _Connectivity_ subscription already configured for regional egress. In this walkthrough, we are going to implement this recommended strategy in an illustrative manner, however you will need to adjust based on your specific situation when you implement this cluster for production. Hubs are usually a centrally-managed and governed resource in an organization, and not typically workload specific. The steps that follow create the hub (and spokes) as a stand-in for the work that you'd coordinate with your networking team.

> :notebook: See [Azure Architecture Center guidance for PCI-DSS 3.2.1 Requirement 1 in AKS](https://docs.microsoft.com/azure/architecture/reference-architectures/containers/aks-pci/aks-pci-network#requirement-1install-and-maintain-a-firewall-configuration-to-protect-cardholder-data) and [Networking configuration](https://docs.microsoft.com/azure/architecture/reference-architectures/containers/aks-pci/aks-pci-ra-code-assets#networking-configuration).

## Expected results

After executing these steps you'll have the `rg-enterprise-networking-hubs` resource group populated with a regional virtual network (vnet), Azure Firewall, Azure Bastion, and Azure Monitor & Flow Log storage for network observability. No spokes will have been created yet, so the default firewall rules are maximally restrictive, as there is no expected outflow of traffic so none is allowed. We'll open up access on an as-needed bases throughout this walk through.

Specifically, you'll see networking/hub-region.v​_n_.bicep referenced a couple times in this process. Think of this as an evolution of a _single_ template as the number and needs of the connected spokes change over time. You can diff the v​_n_ and v​_n+1_ templates to see this progression over time. Typically your network team would have encapsulated this hub in a file named something like `hub-eastus2.bicep` and updated it in their source control as dependencies/requirements dictate. It likely would have not taken as many parameters as either, as those would be constants that could be easily defined directly in the template as the file would be specific to the region's spokes. To keep this reference implementation more flexible on what region you select, you'll be asked to provide deployment parameters and the filename can remain the generic name of hub-​_region_.

The examples that follow use `eastus2` as the primary region. You're welcome to change this in the Bicep template parameters throughout this walkthrough. Clusters are regional resources; and the expectation is that your regional hub, regional spoke, and regional workload are all sharing the same region. So if you make a change to the region, be sure you change it in _all_ places along the way. For a reference architecture of a general-purpose, multi-region cluster, see [AKS Baseline for Multi-Region Topology](https://github.com/mspnp/aks-baseline-multi-region).

### IP addressing

* Regional Hubs are allocated to `10.200.[0-9].0` in this reference implementation. The `eastus2` hub (created below) will be `10.200.0.0/24`.
* Regional Spokes (created later) in this reference implementation are allocated to `10.240.0.0/16` and `10.241.0.0/28`.

Since this walkthrough is expected to be deployed isolated from existing infrastructure and not joined to any of your existing networks; these IP addresses should not come in conflict with any existing networking you have, even if those IP addresses overlap with ones you already have. However, if you need to join existing networks, even for the purposes this walkthrough, you'll need to adjust the IP space in the ARM templates as per your requirements as to not conflict.

## Steps

1. Create the regional network hub.

   ```bash
   # [This takes about eight minutes to run.]
   az deployment group create -g rg-enterprise-networking-hubs -f networking/hub-region.v0.bicep -p location=eastus2
   ```

   The hub deployment will output the following:

      * `hubVnetId` - which you'll query in future steps when creating connected regional spokes. E.g. `/subscriptions/[subscription id]/resourceGroups/rg-enterprise-networking-hubs/providers/Microsoft.Network/virtualNetworks/vnet-eastus2-hub`

### Next step

:arrow_forward: [Create the AKS jump box image](./06-aks-jumpboximage.md).
