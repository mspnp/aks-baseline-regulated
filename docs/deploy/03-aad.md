# Prep for Microsoft Entra integration

In the prior step, you [procured TLS certificates](./02-ca-certificates.md) for this reference implementation's deployment. Now we'll prepare Microsoft Entra ID for Kubernetes role-based access control (RBAC). This will ensure you have Microsoft Entra security group(s) and user(s) assigned for group-based Kubernetes control plane access.

## Nomenclature

We are giving this cluster a generic identifier that we'll use to build relationships between various resources. We'll assume that _Business Unit 0001_ is building a regulated workload identified internally as _App ID 0005_ in their service tree. To that end, you will see references to `bu0001a0005` throughout the rest of this implementation. Naming conventions are an important organization technique for your resources. For your final implementation, please use what is appropriate for your team/organization.

## Microsoft Entra tenant selection

AKS allows for a separation between Azure management control plane access control and Kubernetes control plane access control. This deployment process, creating and associating Azure resources with each other, is an example of Azure management control plane access. This is a relationship between your Microsoft Entra tenant associated with your Azure subscription and is what grants you the permissions to create networks, clusters, managed identities, and create relationships between them. Kubernetes has it's own control plane, exposed via the Kubernetes Cluster API endpoint, and honors the Kubernetes RBAC authorization model. This endpoint is where `kubectl` commands are executed against, for example.

AKS allows for disparate Microsoft Entra tenants between these two control planes; one tenant can be used for Azure management control plane and another for Kuberentes Cluster API authorization. You can also use the same tenant for both. Some regulated environments may prefer a clear tenant separation to address impact radius and potential lateral movement; at the _significant_ added complexity and cost of managing multiple identity stores. This reference implementation will work with either model. Most customers, even in regulated environments, use a single Microsoft Entra tenant model with added features such as Conditional Access Policies. Ensure your final implementation is aligned with how your organization and compliance requirements dictate identity management.

## Expected results

Following the steps below will result in a Microsoft Entra configuration that will be used for Kubernetes control plane (Cluster API) authorization.

| Object                         | Purpose                                                 |
|--------------------------------|---------------------------------------------------------|
| A Cluster Admin Security Group | Will be mapped to `cluster-admin` Kubernetes role.      |
| A Cluster Admin User           | Represents at least one break-glass cluster admin user. |
| Cluster Admin Group Membership | Association between the Cluster Admin User(s) and the Cluster Admin Security Group. Ideally there would be NO standing group membership associations made, but for the purposes of this material, you should have assigned the admin user(s) created above. |
| _Additional Security Groups_   | _Optional._ A security group (and its memberships) for the other built-in and custom Kubernetes roles you plan on using. |

## Steps

1. Log in to the tenant where Kubernetes Cluster API authorization will be associated with. 🛑

   Capture the Microsoft Entra tenant ID that will be associated with your cluster's Kubernetes RBAC for Cluster API access. This is _typically_ the same tenant as your Azure RBAC, see [Microsoft Entra tenant selection](#Microsoft-Entra-tenant-selection) above for more details. However, if you do not have access to manage Microsoft Entra groups and permissions, you may create a temporary tenant specifically for this walkthrough so that you're not blocked at this point.

   ```bash
   az login -t <Replace-With-ClusterApi-AzureAD-TenantId> --allow-no-subscriptions
   TENANTID_K8SRBAC=$(az account show --query tenantId -o tsv)
   ```

1. Create/identify the Microsoft Entra security group that is going to map to the [Kubernetes Cluster Admin](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles) role `cluster-admin`.

   If you already have a security group that is appropriate for your cluster's admin service accounts, use that group and skip this step. If using your own group or your Microsoft Entra administrator created one for you to use; you will need to update the group name throughout the reference implementation.

   > :warning: This cluster role is the highest-privileged role available in Kubernetes. Members of this group will have _complete access throughout the cluster_. Generally speaking, there should be **no standing access** at this level; and access is [implemented using Just-In-Time AD group membership](https://learn.microsoft.com/azure/aks/managed-aad#configure-just-in-time-cluster-access-with-azure-ad-and-aks) (_Requires Microsoft Entra PIM found in Premium P2 SKU._). In the next step, you'll create a dedicated account for this highly-privileged, administrative role for this walkthrough. Ensure your all of your cluster's RBAC assignments and memberships are maliciously managed and auditable; aligning to minimal or no standing admin permissions and all other organization & compliance requirements.

   ```bash
   AADOBJECTNAME_GROUP_CLUSTERADMIN=cluster-admins-bu0001a000500
   AADOBJECTID_GROUP_CLUSTERADMIN=$(az ad group create --display-name $AADOBJECTNAME_GROUP_CLUSTERADMIN --mail-nickname $AADOBJECTNAME_GROUP_CLUSTERADMIN --description "Principals in this group are cluster admins in the bu0001a000500 cluster." --query id -o tsv)
   ```

1. Create a "break-glass" cluster administrator user for your AKS cluster.

   This steps creates a dedicated account that you can use for cluster administrative access. This account should have no standing permissions on any Azure resources; a compromise of this account then cannot be parlayed into Azure management control plane access. If using the same tenant that your Azure resources are managed with, some organizations employ an alt-account strategy. In that case, your cluster admins' alt account(s) might satisfy this step.

   ```bash
   TENANTDOMAIN_K8SRBAC=$(az ad signed-in-user show --query 'userPrincipalName' -o tsv | cut -d '@' -f 2 | sed 's/\"//')
   AADOBJECTNAME_USER_CLUSTERADMIN=bu0001a000500-admin
   AADOBJECTID_USER_CLUSTERADMIN=$(az ad user create --display-name=${AADOBJECTNAME_USER_CLUSTERADMIN} --user-principal-name ${AADOBJECTNAME_USER_CLUSTERADMIN}@${TENANTDOMAIN_K8SRBAC} --force-change-password-next-sign-in --password ChangeMebu0001a0005AdminChangeMe --query id -o tsv)
   ```

1. Add the cluster admin user(s) to the cluster admin security group.

   ```bash
   az ad group member add -g $AADOBJECTID_GROUP_CLUSTERADMIN --member-id $AADOBJECTID_USER_CLUSTERADMIN
   ```

1. Create/identify additional security groups to map onto other Kubernetes RBAC roles. _Optional._

   Kubernetes has [built-in, user-facing roles](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles) like _admin_, _edit_, and _view_, generally to be applied at namespace levels, which can also be mapped to various Microsoft Entra groups. Likewise, if you know you'll have additional _custom_ Kubernetes roles created as part of your [separation of duties authentication schema](../rbac-suggestions.md), you can create those security groups now as well. For this walk through, you do NOT need to map any of these additional roles.

   In the [`cluster-rbac.yaml` file](/cluster-manifests/cluster-rbac.yaml) and the various namespaced [`rbac.yaml files`](/cluster-manifests/cluster-baseline-settings/rbac.yaml), you can uncomment what you wish and replace the `<replace-with-an-aad-group-object-id…>` placeholders with corresponding new or existing AD groups that map to their purpose for this cluster or namespace. You do not need to perform this action for this walk through; they are only here for your reference. By default, in this implementation, no additional _cluster_ roles will be bound other than `cluster-admin`. For your final implementation, create custom kubernetes roles to align specifically with those job functions of your team, and create role assignments as needed. Handle [JIT access](https://learn.microsoft.com/azure/active-directory/privileged-identity-management/groups-features) at the group membership level in Microsoft Entra ID via Privileged Identity Management, and leverage conditional access policies where possible. Always strive to minimize standing permissions, especially on identities that have access to in-scope components.

1. Set up Microsoft Entra Conditional Access policies. _Optional. Requires Microsoft Entra ID P1 or P2._

   To support an even stronger authentication model, consider [setting up Conditional Access Policies in Microsoft Entra ID for your cluster](https://learn.microsoft.com/azure/aks/managed-aad#use-conditional-access-with-azure-ad-and-aks). This allows you to further apply restrictions on access to the Kubernetes control plane (e.g. management commands executed through `kubectl`). With conditional access policies in place, you can for example, _require_ multi-factor authentication, restrict authentication to devices that are managed by your Microsoft Entra tenant, or block non-typical sign-in attempts. You will want to apply this to Microsoft Entra groups that are assigned to your cluster with permissions you deem warrant the extra policies (most notability the cluster admin group created above). You will not be setting that up as part of this walkthrough.

   > :notebook: See [Azure Architecture Center guidance for PCI-DSS 3.2.1 Requirement 8.2 in AKS](https://learn.microsoft.com/azure/architecture/reference-architectures/containers/aks-pci/aks-pci-identity#requirement-82).
   

### Next step

:arrow_forward: [Prepare the target subscription](./04-subscription.md)
