# Prerequisites

This is the starting point for the end-to-end instructions on deploying the [AKS Baseline for Regulated Workloads reference implementation](/README.md). There is required access and tooling you'll need in order to accomplish this. Follow the instructions here and on the subsequent pages so that you can get your environment and subscription ready to proceed with the AKS cluster creation.

Throughout this walkthrough, take note of the following symbol.

>🛑 -  **Manual Modification Required**. When this symbol appears on a step, you will need to modify the commands as indicated prior to running them.

## Steps

1. An Azure subscription. If you don't have an Azure subscription, you can create a [free account](https://azure.microsoft.com/free).

   > 💡 The user initiating the following deployment process *must* have the following minimal set of Azure role-based access control (RBAC) roles:
   >
   > - [Contributor role](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#contributor) is *required* at the *subscription* level to have the ability to create resource groups, create and assign Azure Policy, and perform deployments at both the subscription and resource group level.
   > - [User Access Administrator role](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#user-access-administrator) is *required* at the subscription level since you'll be performing role assignments to managed identities across various resource groups.

1. A Microsoft Entra tenant to associate your Kubernetes RBAC Cluster API authentication to.

   > 💡 The user or service principal initiating the deployment process *must* have the following minimal set of Microsoft Entra permissions assigned:
   >
   > - Microsoft Entra [User Administrator](https://learn.microsoft.com/entra/identity/role-based-access-control/permissions-reference#user-administrator-permissions) is *required* to create a "break glass" AKS admin Microsoft Entra security group and user. Alternatively, you could get your Microsoft Entra admin to create this for you when instructed to do so. If you are not assigned the User Administrator permission in the tenant associated to your Azure subscription, consider [creating a new tenant](https://learn.microsoft.com/entra/fundamentals/create-new-tenant#create-a-new-tenant-for-your-organization) to use while evaluating this implementation.

   The Microsoft Entra tenant backing your Cluster's API RBAC does NOT need to be the same tenant associated with your Azure subscription. Your organization may have dedicated Microsoft Entra tenants used specifically as a separation between Azure resource management, and Kubernetes control plane access. Ensure you're following your organization's practices when it comes to separation of identity stores to ensure limited "blast radius" on any compromised accounts.

1. Latest [Azure CLI installed](https://learn.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest) (must be at least 2.52), or you can perform this from Azure Cloud Shell by clicking below.

   [![Launch Azure Cloud Shell](https://learn.microsoft.com/azure/includes/media/cloud-shell-try-it/hdi-launch-cloud-shell.png)](https://shell.azure.com/bash)

   Ensure you're signed in to the subscription in which you plan on deploying this reference to.

1. While the following features are still in *preview*, enable them in your target subscription.

   *None. This reference implementation currently does not use any preview features.*

1. Fork this repository and clone it locally. 🛑

   ```bash
   GITHUB_ACCOUNT_NAME=YOUR-GITHUB-ACCOUNT-NAME-GOES-HERE

   git clone https://github.com/${GITHUB_ACCOUNT_NAME}/aks-baseline-regulated.git
   cd aks-baseline-regulated
   ```

   > 💡 The steps shown here and elsewhere in the reference implementation use Bash shell commands. On Windows, you can use the [Windows Subsystem for Linux](https://learn.microsoft.com/windows/wsl/about#what-is-wsl-2) to run Bash.

1. Ensure [OpenSSL is installed](https://github.com/openssl/openssl#download) in order to generate the example self-signed certs used in this implementation. *OpenSSL is already installed in Azure Cloud Shell.*

### Next step

:arrow_forward: [Generate TLS Certificates](./02-ca-certificates.md).
