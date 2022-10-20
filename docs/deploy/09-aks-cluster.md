# Deploy the Regulated Industries AKS Cluster

Now that the [hub-spoke network is provisioned](./08-cluster-networking.md), the next step in the [AKS Baseline for Regulated workloads reference implementation](/) is deploying the AKS cluster, built on it's [security-hardened OS](https://learn.microsoft.com/azure/aks/security-hardened-vm-host-image) and its adjacent Azure resources.

## Expected results

* The cluster and all adjacent resources are deployed.
  * This includes core infrastructure such as Azure Key Vault, Azure Container Registry, and Azure Application Gateway.
  * Private Link configuration
  * Jump box (Azure Bastion) access
* A wildcard TLS certificate (`*.aks-ingress.contoso.com`) is imported into Azure Key Vault that will be used by your workload's ingress controller to expose an HTTPS endpoint to Azure Application Gateway.
* A Pod Managed Identity (`podmi-ingress-controller`) is deployed to the `ingress-nginx` namespace and ready to be bound via the name `podmi-ingress-controller`.
  * The same managed identity is granted the ability to pull the ingress controller's own TLS certificate from Key Vault.

## Steps

1. Get the already-deployed, virtual network resource ID that this cluster will be attached to.

   ```bash
   RESOURCEID_VNET_CLUSTERSPOKE=$(az deployment group show -g rg-enterprise-networking-spokes -n spoke-BU0001A0005-01 --query properties.outputs.clusterVnetResourceId.value -o tsv)
   ```

1. Identify your jump box image.

   ```bash
   # If you used a pre-existing image and not the one built by this walk through, replace the command below with the resource id of that image.
   RESOURCEID_IMAGE_JUMPBOX=$(az deployment group show -g rg-bu0001a0005 -n CreateJumpBoxImageTemplate --query 'properties.outputs.distributedImageResourceId.value' -o tsv)
   ```

1. Convert your jump box cloud-init (users) file to Base64.

   ```bash
   CLOUDINIT_BASE64=$(base64 jumpBoxCloudInit.yml | tr -d '\n')
   ```

   If you need to perform this in Powershell, you can achieve the same with this.

   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes('jumpBoxCloudInit.yml'))
   ```

1. Deploy the cluster ARM template.

   > _Alteratively 🛑_, you could set these values in [`azuredeploy.parameters.prod.json`](../../azuredeploy.parameters.prod.json) file instead of the individual key-value pairs shown below. You'll be redeploying a slight evolution of this template a later time in this walkthrough, and you might find it easier to have these variables captured in the parameters file as they will not change for the second deployment.

   ```bash
   # [This takes about 20 minutes to run.]
   az deployment group create -g rg-bu0001a0005 -f cluster-stamp.bicep -p targetVnetResourceId=${RESOURCEID_VNET_CLUSTERSPOKE} clusterAdminAadGroupObjectId=${AADOBJECTID_GROUP_CLUSTERADMIN} k8sControlPlaneAuthorizationTenantId=${TENANTID_K8SRBAC} appGatewayListenerCertificate=${APP_GATEWAY_LISTENER_CERTIFICATE_BASE64} aksIngressControllerCertificate=${INGRESS_CONTROLLER_CERTIFICATE_BASE64} jumpBoxImageResourceId=${RESOURCEID_IMAGE_JUMPBOX} jumpBoxCloudInitAsBase64=${CLOUDINIT_BASE64}

   # Or if you updated and wish to use the parameters file …
   #az deployment group create -g rg-bu0001a0005 -f cluster-stamp.bicep -p "@azuredeploy.parameters.prod.json"
   ```

1. Update cluster deployment with managed identity assignments.

   **cluster-stamp.v2.json** is a _tiny_ evolution of the **cluster-stamp.bicep** ARM template you literally just deployed in the step above. Because we are using Azure AD Pod Identity v1 as a Microsoft-managed add-on, the mechanism to associate identities with the cluster is via ARM template instead of via Kubernetes manifest deployments (as you would do with the vanilla open source solution). However, due to a current limitation of the add-on, managed identities for Pod Managed Identities CANNOT be associated to the cluster when the cluster is first being created, only as an update to an existing cluster. So this deployment will re-deploy with the Pod Managed Identity association as the _only change_. Pod Managed Identity v2 is in development and it will support assignment at cluster-creation time. This implementation will evolve to use Azure AD Pod Identity v2 when available and we'll remove this step and add the assignment directly in `cluster-stamp.bicep`.

   > :eyes: If you're curious to see what changed in the cluster stamp, [view the diff](https://diffviewer.azureedge.net/?l=https://raw.githubusercontent.com/mspnp/aks-baseline-regulated/main/cluster-stamp.bicep&r=https://raw.githubusercontent.com/mspnp/aks-baseline-regulated/main/cluster-stamp.v2.bicep).

   ```bash
   # [This takes about five minutes to run.]
   az deployment group create -g rg-bu0001a0005 -f cluster-stamp.v2.bicep -p targetVnetResourceId=${RESOURCEID_VNET_CLUSTERSPOKE} clusterAdminAadGroupObjectId=${AADOBJECTID_GROUP_CLUSTERADMIN} k8sControlPlaneAuthorizationTenantId=${TENANTID_K8SRBAC} appGatewayListenerCertificate=${APP_GATEWAY_LISTENER_CERTIFICATE_BASE64} aksIngressControllerCertificate=${AKS_INGRESS_CONTROLLER_CERTIFICATE_BASE64} jumpBoxImageResourceId=${RESOURCEID_IMAGE_JUMPBOX} jumpBoxCloudInitAsBase64=${CLOUDINIT_BASE64}

   # Or if you used the parameters file …
   #az deployment group create -g rg-bu0001a0005 -f cluster-stamp.v2.json -p "@azuredeploy.parameters.prod.json"
   ```

## Import the wildcard certificate for the AKS ingress controller to Azure Key Vault

Once web traffic hits Azure Application Gateway, public-facing TLS is terminated. This supports WAF inspection rules and other request manipulation features of Azure Application Gateway. The next hop for this traffic is to the internal layer 4 load balancer and then to the in-cluster ingress controller. Starting at Application Gateway, all subsequent network hops are done via your private virtual network and is no longer traversing any public networks. That said, we still desire to provide TLS as an added layer of protection when traversing between Azure Application Gateway and our ingress controller. That'll bring TLS encryption _into_ your cluster from Application Gateway.

### Steps

1. Give your user temporary permissions to import certificates into Key Vault.

   ```bash
   KEYVAULT_NAME=$(az deployment group show --resource-group rg-bu0001a0005 -n cluster-stamp --query properties.outputs.keyVaultName.value -o tsv)
   az keyvault set-policy --certificate-permissions import --upn $(az account show --query user.name -o tsv) -n $KEYVAULT_NAME
   ```

1. Import the AKS ingress controller's certificate.

   You currently cannot import certificates into Key Vault directly via ARM templates. As such, post deployment of our Azure resources (which includes Key Vault), you need to upload your ingress controller's wildcard certificate to Key Vault. This is the `.pem` file you created on a prior page. Your ingress controller will authenticate to Key Vault (via the Pod Managed Identity created above) and use this certificate as its default TLS certificate, presenting exclusively to your Azure Application Gateway.

   ```bash
   az keyvault certificate import -f ingress-internal-aks-ingress-contoso-com-tls.pem -n ingress-internal-aks-ingress-contoso-com-tls --vault-name $KEYVAULT_NAME
   ```

1. Remove the temporary import certificates permissions for current user.

   > The Azure Key Vault Policy for your user was a temporary policy to allow you to import the certificate for this walkthrough. In actual deployments, you would manage access policies like these via your ARM templates using [Azure RBAC for Key Vault data plane](https://learn.microsoft.com/azure/key-vault/general/secure-your-key-vault#data-plane-and-access-policies).

   ```bash
   az keyvault delete-policy --upn $(az account show --query user.name -o tsv) -n $KEYVAULT_NAME
   ```

At this point, you have a cluster and its adjacent resources deployed, but it isn't bootstrapped yet. A bootstrapped cluster is one that has a base (think cluster-wide, workload agnostic) set of security agents, configurations, etc. applied even before you get any workloads lit up. The bootstrapping of a cluster should be an immediate-follow after deployment of your cluster, and should be automated along with the deployment of your cluster. The following steps will walk through the process manually so that you understand an example of what could be a starting point for your post-deployment bootstrapping.

## Container registry note

In this reference implementation, Azure Policy _and_ Azure Firewall are blocking all container registries other than Microsoft Container Registry and your private ACR instance deployed with this reference implementation. This will protect your cluster from unapproved registries being used; which may prevent issues while trying to pull images from a registry which doesn't provide an appropriate SLO and also help meet compliance needs for your container image supply chain.

This deployment creates an SLA-backed Azure Container Registry for your cluster's needs. Your organization may have a central container registry for you to use, or your registry may be tied specifically to your application's infrastructure (as demonstrated in this implementation). **Only use container registries that satisfy the availability and compliance needs of your workload.**

### Next step

:arrow_forward: [Prepare to bootstrap the cluster](./10-pre-bootstrap.md)
