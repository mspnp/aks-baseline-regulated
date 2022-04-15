# Clean up

After you are done exploring your deployed [AKS Baseline Cluster for Regulated Workloads](/), you'll want to delete the created Azure resources to prevent undesired costs from accruing. Follow these steps to delete all resources created as part of this reference implementation.

## Steps

1. Delete flow logs

   The `networkWatcherRG` resource group is where flow log definitions were created for this reference implementation.  All of the flow logs that were created were prefixed with `fl` and were followed by a GUID, targeting a virtual network either in the hub or spokes resource group.

1. Delete the resource groups as a way to delete all contained Azure resources.

   > To delete all Azure resources associated with this reference implementation, you'll need to delete the three resource groups created.

   :warning: Ensure you are using the correct subscription, and validate that the only resources that exist in these groups are ones you're okay deleting.

   ```bash
   az group delete -n rg-bu0001a0005
   az group delete -n rg-enterprise-networking-spokes
   az group delete -n rg-enterprise-networking-hubs
   ```

   Depending on your subscription's starting point, this walkthrough might have also deployed a resource group by the name of `networkWatcherRG`. If you know this to be the case, and wish to remove it as well, you can execute `az group delete -n networkWatcherRG`. If you are not sure, you can leave that resource group in place, the resources deployed as part of this walkthrough to that resource group are not cost or security impacting.

1. Purge Azure Key Vault

   > Because this reference implementation enables soft delete on Key Vault, execute a purge so your next deployment of this implementation doesn't run into a naming conflict.

   ```bash
   az keyvault purge -n ${KEYVAULT_NAME}
   ```

1. If any temporary changes were made to Azure AD or Azure RBAC permissions consider removing those as well.

1. [Remove the Azure Policy assignments](https://portal.azure.com/#blade/Microsoft_Azure_Policy/PolicyMenuBlade/Compliance) scoped to the cluster's resource group. To identify those created by this implementation, look for ones that are prefixed with `[your-cluster-name] ` and `[your-resource-group-names] `.  If you added **Azure Security Benchmark** or **Enable Microsoft Defender Standard** as part of this as well, you may choose to remove them as well.

   Execute the following commands will handle all Resource Group-scoped policies:

   ```bash
   for p in $(az policy assignment list --disable-scope-strict-match --query "[?resourceGroup=='rg-bu0001a0005'].name" -o tsv); do az policy assignment delete -n ${p} -g rg-bu0001a0005; done
   for p in $(az policy assignment list --disable-scope-strict-match --query "[?resourceGroup=='rg-enterprise-networking-spokes'].name" -o tsv); do az policy assignment delete -n ${p} -g rg-enterprise-networking-spokes; done
   for p in $(az policy assignment list --disable-scope-strict-match --query "[?resourceGroup=='rg-enterprise-networking-hubs'].name" -o tsv); do az policy assignment delete -n ${p} -g rg-enterprise-networking-hubs; done
   ```

1. Remove _custom_ Azure Policy definitions.

   From the [Azure Policy Definitions](https://portal.azure.com/#blade/Microsoft_Azure_Policy/PolicyMenuBlade/Definitions) page in the Azure Portal, remove any custom definitions that were included with this walkthrough. This is the **Enable Microsoft Defender Standard** initiative, also the **Public network access on AKS API should be disabled**, **WAF SKU must be enabled on Azure Application Gateway**, **Microsoft Defender for Containers is enabled**, **Microsoft Defender for Containers should be enabled in the cluster.**, and **Microsoft Defender for Key Vault is enabled** policies. Ensure you do not delete any custom policies that are current assigned to your subscription or policies that were not created through this walkthrough.

1. If Microsoft Defender for Cloud was turned on temporarily for this, consider turning that off as well.

   **Do not disable any security controls that were already in place on your subscription before starting this walkthrough.**

   1. Go to the [**Pricings & Settings** view in Microsoft Defender for Cloud](https://portal.azure.com/#blade/Microsoft_Azure_Security/SecurityMenuBlade/24)
   1. Select your subscription.
   1. Turn "Off" any **Microsoft Defender for _topic_** that you might have enabled exclusively due to this walkthrough only.

### Next step

:arrow_forward: [Back to main README](/README.md)
