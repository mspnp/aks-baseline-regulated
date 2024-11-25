# Prep for cluster bootstrapping

Now that the [hub-spoke network is provisioned](./08-cluster-networking.md), the next step in the [AKS baseline for regulated workloads reference implementation](./) is preparing what your AKS cluster should be bootstrapped with.

## Expected results

### Container Registry

Container registries often have a lifecycle that extends beyond the scope of a single cluster. They can be scoped broadly at organizational or business unit levels, or can be scoped at workload levels, but usually are not directly tied to the lifecycle of any specific cluster instance. For example, you may do blue/green *cluster instance* deployments, both using the same Container Registry. Even though clusters came and went, the registry stays intact.

- Azure Container Registry is deployed, and exposed as a private endpoint.
- Azure Container Registry is populated with images your cluster will need as part of its bootstrapping process.
- Log Analytics is deployed and Azure Container Registry platform logging is configured. This workspace will be used by your cluster as well.

The role of this pre-existing Azure Container Registry instance is made more prominant when we think about cluster bootstrapping. That is the process that happens after Azure resource deployment of the cluster, but before your first workload lands in the cluster. The cluster will be bootstrapped *immediately and automatically* after cluster deployment by the GitOps extension, which means you'll need Azure Container Registry in place to act as your official OCI artifact repository for required images and Helm charts used in that bootstrapping process.

### Key Vault

Azure Key Vault also often has a lifecycle that extends beyond the scope of a single cluster. It is used to hold certificates needed by various components in the infrastructure and needs to be in place for when the cluster is bootstrapped.

A wildcard TLS certificate (`*.aks-ingress.contoso.com`) is imported into Azure Key Vault that will be used by your workload's ingress controller to expose an HTTPS endpoint to Azure Application Gateway.

### Managed identities

An Azure user managed identity is going to be deployed. This identity is the ingress controller's workload identity and will be set up with RBAC access to Key Vault for successful bootstrapping.

## Steps

1. Get the AKS cluster spoke Virtual Network resource ID.

   > :book: The app team will be deploying to a spoke Virtual Network, that was already provisioned by the network team.

   ```bash
   export RESOURCEID_VNET_CLUSTERSPOKE=$(az deployment group show -g rg-enterprise-networking-spokes-centralus -n spoke-BU0001A0005-01 --query properties.outputs.clusterVnetResourceId.value -o tsv)
   echo RESOURCEID_VNET_CLUSTERSPOKE: $RESOURCEID_VNET_CLUSTERSPOKE
   ```

1. Deploy the bootstrapping resources template.

   ```bash
   # [This takes about eight minutes.]
   az deployment group create -g rg-bu0001a0005-centralus -f pre-cluster-stamp.bicep -p targetVnetResourceId=${RESOURCEID_VNET_CLUSTERSPOKE} aksIngressControllerCertificate=${INGRESS_CONTROLLER_CERTIFICATE_BASE64}
   ```

## Quarantine pattern

Quarantining first- and third-party images is a recommended security practice. This allows you to get your images onto a dedicated container registry and subject them to any sort of security/compliance scrutiny you wish to apply. Once validated, they can then be promoted to being available to your cluster. There are many variations on this pattern, with different tradeoffs for each. For simplicity in this walkthrough we are simply going to import our images to repository names that starts with `quarantine/`. We'll then show you Microsoft Defender for Containers' scan of those images, and then you'll import those same images directly from `quarantine/` to `live/` repositories (retaining their sha256 digest). We've restricted our cluster to only allow pulling from `live/` repositories and we've built an alert if an image was imported to `live/` from a source other than `quarantine/`. This isn't a preventative security control; *this won't block a direct import* request or *validate* that the image actually passed quarantine checks. There are other solutions you can use for this pattern that are more exhaustive. [Aquasec](https://go.microsoft.com/fwlink/?linkid=2002601&clcid=0x409) and [Twistlock](https://go.microsoft.com/fwlink/?linkid=2002600&clcid=0x409) both offer integrated solutions specifically for Azure Container Registry scanning and compliance management. Azure Container Registry has an [integrated quarantine feature](https://learn.microsoft.com/azure/container-registry/container-registry-faq#how-do-i-enable-automatic-image-quarantine-for-a-registry) as well that could be considered, however it is in preview at this time.

> :notebook: For more information, see [Azure Architecture Center guidance for PCI DSS 3.2.1 Requirement 6.3.2 in AKS](https://learn.microsoft.com/azure/architecture/reference-architectures/containers/aks-pci/aks-pci-malware#requirement-632).

### Deployment pipelines

Your deployment pipelines are one of the first lines of defense in container image security. Shifting left by introducing build steps like [GitHub Image Scanning](https://github.com/Azure/container-scan) (which uses common tools like [dockle](https://github.com/goodwithtech/dockle) and [Aquasec trivy](https://github.com/aquasecurity/trivy)) will help ensure that, at build time, your images are linted, CIS benchmarked, and free from known vulnerabilities. You can use any tooling at this step that you trust, including paid, ISV solutions that help provide your desired level of confidence and compliance.

Once your images are built (or identified from a public container registry such as Docker Hub or GitHub Container Registry), the next step is pushing/importing those images to your own container registry. This is the next place a security audit should take place and is in fact the quarantine process identified above. Your newly pushed images undergo any scanning desired. Your pipeline should be gated on the outcome of that scan. If the scan is complete and returned sufficiently healthy results, then your pipeline should move the image into your final container registry repository. If the scan does not complete or is not found sufficiently healthy, you stop that deployment immediately.

### Continuous scanning

The quarantine pattern is ideal for detecting issues with newly pushed images, but *continuous scanning* is also desirable as CVEs can be found at any time for your images that are in use. **Microsoft Defender for containers** will perform daily scanning of active images and also provide [run-time visibility of vulnerabilities](https://learn.microsoft.com/azure/defender-for-cloud/defender-for-containers-introduction?tabs=defender-for-container-arch-aks#scanning-images-at-runtime) by grouping them and providing details about the issues discovered and how to remediate them. Third-party ISV solutions can perform similar tasks. It is recommended that you implement continuous scanning at the registry level. Microsoft Defender for containers currently has limitations with private Azure Container Registry instances (such as yours, exposed exclusively via Private Link). Ensure your continuous scan solution can work within your network restrictions. You may need to bring a third-party ISV solution into network adjacency to your container registry to be able to perform your desired scanning. How you react to a CVE (or other issue) detected in your images should be documented in your security operations playbooks. For example, you could remove the image from being available to pull, but that could cause a downstream outage while you're remediating.

### In-cluster scanning

Using a security agent that is container-aware and can operate from within the cluster is another layer of defense, and is the closest to the actual runtime. This should be used to detect threats that were not detectable in an earlier stage, such as reporting on CVE issues on your current running inventory or unexpected runtime behavior. Having an in-cluster runtime security agent be your *only* issue detection point is *too late* in the process. These agents come at a cost (compute power, operational complexity, their own security posture), but are often still considered a valuable addition to your overall defense in depth position. This topic is covered a bit more on the next page.

**Static analysis, registry scanning, and continuous scanning should be the workflow for all of your images; both your own first party and any third party images you use.**

> :notebook: For more information, see [Azure Architecture Center guidance for PCI-DSS 3.2.1 Requirement 5 & 6 in AKS](https://learn.microsoft.com/azure/architecture/reference-architectures/containers/aks-pci/aks-pci-malware).

## Steps

1. Quarantine public bootstrap security/utility images.

   ```bash
   # Get your quarantine Azure Container Registry service name
   # You only deployed one ACR instance in this walkthrough, but this could be
   # a separate, dedicated quarantine instance managed by your IT team.
   ACR_NAME_QUARANTINE=$(az deployment group show -g rg-bu0001a0005-centralus -n pre-cluster-stamp --query properties.outputs.quarantineContainerRegistryName.value -o tsv)

   # [Combined this takes about eight minutes.]
   az acr import --source docker.io/falcosecurity/falco-no-driver:0.39.2 -t quarantine/falcosecurity/falco-no-driver:0.39.2 -n $ACR_NAME_QUARANTINE         && \
   az acr import --source docker.io/falcosecurity/falco-driver-loader:0.39.2 -t quarantine/falcosecurity/falco-driver-loader:0.39.2 -n $ACR_NAME_QUARANTINE && \
   az acr import --source docker.io/falcosecurity/falcoctl:0.10.1 -t quarantine/falcosecurity/falcoctl:0.10.1 -n $ACR_NAME_QUARANTINE && \
   az acr import --source docker.io/library/busybox:1.37.0 -t quarantine/library/busybox:1.37.0 -n $ACR_NAME_QUARANTINE                                     && \
   az acr import --source ghcr.io/kubereboot/kured:1.14.0 -t quarantine/kubereboot/kured:1.14.0 -n $ACR_NAME_QUARANTINE                                     && \
   az acr import --source registry.k8s.io/ingress-nginx/controller:v1.11.3 -t quarantine/ingress-nginx/controller:v1.11.3 -n $ACR_NAME_QUARANTINE && \
   az acr import --source registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.4.4 -t quarantine/ingress-nginx/kube-webhook-certgen:v1.4.4 -n $ACR_NAME_QUARANTINE
   ```

   > The above imports account for 100% of the containers that you are actively bringing to the cluster, but not those that come with the AKS service itself nor any of its add-ons or extensions. Those images, outside of your direct control, are all sourced from Microsoft Container Registry's (MCR). While you do not have an affordance to inject yourself in the middle of their distribution to your cluster, you can still pull those images through your inspection process for your own audit and reporting purposes. *All container images that you directly bring to the cluster should pass through your quarantine process.* The *allowed images* Azure Policy associated with this cluster should be configured to match your specific needs. Be sure to update `allowedContainerImagesRegex` in [`cluster-stamp.json`](../../cluster-stamp.json) to define expected image sources to whatever specificity is manageable for you. Never allow a source that you do not intend to use. For example, if you do not bring Open Service Mesh into your cluster, you can remove the existing allowance for `mcr.microsoft.com` as a valid source of images, leaving just `<your acr instance>/live/` repositories as the only valid source for non-system namespaces.

1. Run security audits on images.

   If you had sufficient permissions when we did [subscription configuration](./04-subscription.md), Microsoft Defender for containers is enabled on your subscription. Microsoft Defender for containers will begin [scanning all newly imported images](https://learn.microsoft.com/azure/security-center/defender-for-container-registries-introduction#when-are-images-scanned) in your Azure Container Registry using a Microsoft hosted version of Qualys. The results of those scans will be available in Microsoft Defender for Cloud within 15 minutes. *If Microsoft Defender for containers is not enabled on your subscription, you can skip this step.*

   To see the scan results in Microsoft Defender for Cloud, perform the following actions:

   1. Open the [Microsoft Defender for Cloud's **Recommendations** page](https://portal.azure.com/#blade/Microsoft_Azure_Security/SecurityMenuBlade/5).
   1. Click **Add filter**, select `Resource Type` and check **Container Images**.
   1. Click on the first listed recommendation with title **Container images in Azure registry should have vulnerability findings resolved**.
   1. Click **View recommendations for all resources**.
   1. Expand **Affected resources**.

   In here, you can see the status of each container images:
    - **Unhealthy**, which means a scan detected a problem with the image.
    - **Healthy**, which means the image was scanned, but didn't result in any problems.
    - **Unverified**, which means the image couldn't be scanned.
    - **Not applicable resources**, which means that the image was unable to be scanned. For more information on images that can't be scanned, see [Registries and images support for Azure](/azure/defender-for-cloud/support-matrix-defender-for-containers#registries-and-images-support-for-azure---vulnerability-assessment-powered-by-microsoft-defender-vulnerability-management).

   As with any Microsoft Defender for Cloud product, you can set up alerts or via your connected SIEM to be identified when an issue is detected. Periodically checking and discovering security alerts via the Azure Portal is not the expected method to consume these security status notifications. No Microsoft Defender for Cloud alerts are currently configured for this walkthrough.

   **There is no action for you to take, in this step.** This was just a demonstration of Microsoft Defender for Cloud's scanning features. Ultimately, you'll want to build a quarantine pipeline that solves for your needs and aligns with your image deployment strategy and supply chain requirements.

1. Release bootstrap images from quarantine.

   ```bash
   # Get your live Azure Container Registry service name
   ACR_NAME=$(az deployment group show -g rg-bu0001a0005-centralus -n pre-cluster-stamp --query properties.outputs.containerRegistryName.value -o tsv)

   # [Combined this takes about eight minutes.]
   az acr import --source quarantine/falcosecurity/falco-no-driver:0.39.2 -r $ACR_NAME_QUARANTINE -t live/falcosecurity/falco-no-driver:0.39.2 -n $ACR_NAME         && \
   az acr import --source quarantine/falcosecurity/falco-driver-loader:0.39.2 -r $ACR_NAME_QUARANTINE -t live/falcosecurity/falco-driver-loader:0.39.2 -n $ACR_NAME && \
   az acr import --source quarantine/falcosecurity/falcoctl:0.10.1 -r $ACR_NAME_QUARANTINE -t live/falcosecurity/falcoctl:0.10.1 -n $ACR_NAME && \
   az acr import --source quarantine/library/busybox:1.37.0 -r $ACR_NAME_QUARANTINE -t live/library/busybox:1.37.0 -n $ACR_NAME                                     && \
   az acr import --source quarantine/kubereboot/kured:1.14.0 -r $ACR_NAME_QUARANTINE -t live/kubereboot/kured:1.14.0 -n $ACR_NAME                                   && \
   az acr import --source quarantine/ingress-nginx/controller:v1.11.3 -r $ACR_NAME_QUARANTINE -t live/ingress-nginx/controller:v1.11.3 -n $ACR_NAME && \
   az acr import --source quarantine/ingress-nginx/kube-webhook-certgen:v1.4.4 -r $ACR_NAME_QUARANTINE -t live/ingress-nginx/kube-webhook-certgen:v1.4.4 -n $ACR_NAME
   ```

1. Trigger quarantine violation. *Optional.*

   You've deployed an alert called **Image Imported into ACR from source other than approved Quarantine** that will fire if you import an image directly to `live/` without coming from `quarantine/`. If you'd like to see that trigger, go ahead and import an image directly to `live/`. On the validation page later in this walkthrough, you'll see that alert.

   ```bash
   az acr import --source docker.io/library/busybox:1.37.0 -t live/library/busybox:SkippedQuarantine -n $ACR_NAME
   ```

## Container Registry note

In this reference implementation, Azure Policy *and* Azure Firewall are blocking all container registries other than Microsoft Container Registry (MCR) and your private Azure Container Registry instance deployed with this reference implementation. This will protect your cluster from unapproved registries being used, which might prevent issues while trying to pull images from a registry which doesn't provide an appropriate SLO and also help meet compliance needs for your container image supply chain.

This deployment creates an SLA-backed Azure Container Registry for your cluster's needs. Your organization may have a central container registry for you to use, or your registry may be tied specifically to your application's infrastructure (as demonstrated in this implementation). **Only use container registries that satisfy the availability and compliance needs of your workload.**

## Import the wildcard certificate for the AKS ingress controller to Azure Key Vault

Once web traffic hits Azure Application Gateway (deployed in a future step), public-facing TLS is terminated. This supports WAF inspection rules and other request manipulation features of Azure Application Gateway. The next hop for this traffic is to the internal Layer 4 Load Balancer and then to the in-cluster ingress controller. Starting at Application Gateway, all subsequent network hops are done via your private virtual network and is no longer traversing any public networks. That said, we still desire to provide TLS as an added layer of protection when traversing between Azure Application Gateway and our ingress controller. That'll bring TLS encryption *into* your cluster from Application Gateway.

### Steps

1. Obtain the Azure Key Vault details and give the current user permissions and network access to import certificates.

   ```bash
   KEYVAULT_NAME=$(az deployment group show --resource-group rg-bu0001a0005-centralus -n pre-cluster-stamp --query properties.outputs.keyVaultName.value -o tsv)
   TEMP_ROLEASSIGNMENT_TO_UPLOAD_CERT=$(az role assignment create --role a4417e6f-fecd-4de8-b567-7b0420556985 --assignee-principal-type user --assignee-object-id $(az ad signed-in-user show --query 'id' -o tsv) --scope $(az keyvault show --name $KEYVAULT_NAME --query 'id' -o tsv) --query 'id' -o tsv)
   echo TEMP_ROLEASSIGNMENT_TO_UPLOAD_CERT: $TEMP_ROLEASSIGNMENT_TO_UPLOAD_CERT

   # If you are behind a proxy or some other egress that does not provide a consistent IP, you'll need to manually adjust the
   # Azure Key Vault firewall to allow this traffic.
   CURRENT_IP_ADDRESS=$(curl -s -4 https://ifconfig.io)
   echo CURRENT_IP_ADDRESS: $CURRENT_IP_ADDRESS
   az keyvault network-rule add -n $KEYVAULT_NAME --ip-address ${CURRENT_IP_ADDRESS}
   ```

1. Import the AKS ingress controller's certificate.

   You currently cannot import certificates into Key Vault directly via ARM templates. As such, post deployment of our bootstrapping resources (which includes Key Vault), you need to upload your ingress controller's wildcard certificate to Key Vault. This is the `.pem` file you created on a prior page. Your ingress controller will authenticate to Key Vault (via its workload identity) and use this certificate as its default TLS certificate, presenting exclusively to your Azure Application Gateway.

   _As an alternative, this import process could be done with [`deploymentScripts` within the ARM template](https://github.com/Azure/bicep/discussions/8457#discussioncomment-3712980). Use whatever certificate management process your organization and compliance mandates._

   ```bash
   az keyvault certificate import -f ingress-internal-aks-ingress-contoso-com-tls.pem -n ingress-internal-aks-ingress-contoso-com-tls --vault-name $KEYVAULT_NAME
   ```

1. Remove Azure Key Vault import certificates permissions and network access for current user.

   > The Azure Key Vault RBAC assignment for your user and network allowance was temporary to allow you to upload the certificate for this walkthrough. In actual deployments, you would manage these any RBAC policies via your ARM templates using [Azure RBAC for Key Vault data plane](https://learn.microsoft.com/azure/key-vault/general/secure-your-key-vault#data-plane-and-access-policies) and only network-allowed traffic would access your Key Vault.

   ```bash
   az keyvault network-rule remove -n $KEYVAULT_NAME --ip-address ${CURRENT_IP_ADDRESS}
   az role assignment delete --ids $TEMP_ROLEASSIGNMENT_TO_UPLOAD_CERT
   ```

## GitOps Kubernetes manifest updates

Your cluster will be bootstrapped using the Microsoft-provided GitOps extension, and this happens automatically after the cluster is deployed. This means you need to prepare the source repo that contains the manifest files. The following instructions will update a few .yaml files with values specific to your deployment/environment.

### Steps

1. Navigate to the directory containing the manifest files

   ```bash
   cd cluster-manifests
   ```

1. Update kustomization files to use images from your container registry.

   ```bash
   sed -i "s/REPLACE_ME_WITH_YOUR_ACRNAME/${ACR_NAME}/g" */kustomization.yaml

   git commit -a -m "Update bootstrap deployments to use images from my ACR instead of public container registries."
   ```

1. Update Key Vault placeholders in your CSI Secret Store provider.

   You'll be using the [Secrets Store CSI Driver for Kubernetes](https://learn.microsoft.com/azure/aks/csi-secrets-store-driver) to mount the ingress controller's certificate which you stored in Azure Key Vault. Once mounted, your ingress controller will be able to use it. To make the CSI Provider aware of this certificate, it must be described in a `SecretProviderClass` resource. You'll update the supplied manifest file with this information now.

   ```bash
   INGRESS_CONTROLLER_WORKLOAD_IDENTITY_CLIENT_ID_BU0001A0005_01=$(az deployment group show --resource-group rg-bu0001a0005-centralus -n pre-cluster-stamp --query properties.outputs.ingressClientid.value -o tsv)
   echo INGRESS_CONTROLLER_WORKLOAD_IDENTITY_CLIENT_ID_BU0001A0005_01: $INGRESS_CONTROLLER_WORKLOAD_IDENTITY_CLIENT_ID_BU0001A0005_01

   sed -i -e "s/KEYVAULT_NAME/${KEYVAULT_NAME}/" -e "s/KEYVAULT_TENANT/${TENANTID_AZURERBAC}/" -e "s/INGRESS_CONTROLLER_WORKLOAD_IDENTITY_CLIENT_ID_BU0001A0005_01/${INGRESS_CONTROLLER_WORKLOAD_IDENTITY_CLIENT_ID_BU0001A0005_01}/" ingress-nginx/akv-tls-provider.yaml

   git commit -a -m "Update SecretProviderClass to reference my ingress controller certificate."
   ```

1. Push those two commits to your repo.

   ```bash
   git push
   cd ..
   ```

### Next step

:arrow_forward: [Deploy the AKS cluster](./10-aks-cluster.md)
