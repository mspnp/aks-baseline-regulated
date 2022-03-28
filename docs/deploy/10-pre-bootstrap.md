# Prepare to bootstrap the cluster

Now that [the AKS cluster](./09-aks-cluster.md) has been deployed, the next step is to talk a bit about container image security, starting with the images you'll be using to bootstrap this cluster.

## Expected results

Your cluster is about to be bootstrapped with some base operating container images. These components will place your cluster under GitOps control and will install foundational security elements and any other cluster-wide resources you want deployed before workloads start landing on the cluster. This means this is the first time we'll be bringing images directly into this cluster.

You'll end up with the following images imported into your ACR instance, after having passed through a _simulated_ quarantine process.

* Flux
* Falco
* Busybox
* Kured
* NGINX Ingress Controller

## Quarantine pattern

Quarantining first- and third-party images is a recommended security practice. This allows you to get your images onto a dedicated container registry and subject them to any sort of security/compliance scrutiny you wish to apply. Once validated, they can then be promoted to being available to your cluster. There are many variations on this pattern, with different tradeoffs for each. For simplicity in this walkthrough we are simply going to import our images to repository names that starts with `quarantine/`. We'll then show you Microsoft Defender for Containers' scan of those images, and then you'll import those same images directly from `quarantine/` to `live/` repositories (retaining their sha256 digest). We've restricted our cluster to only allow pulling from `live/` repositories and we've built an alert if an image was imported to `live/` from a source other than `quarantine/`. This isn't a preventative security control; _this won't block a direct import_ request or _validate_ that the image actually passed quarantine checks. There are other solutions you can use for this pattern that are more exhaustive. [Aquasec](https://go.microsoft.com/fwlink/?linkid=2002601&clcid=0x409) and [Twistlock](https://go.microsoft.com/fwlink/?linkid=2002600&clcid=0x409) both offer integrated solutions specifically for Azure Container Registry scanning and compliance management. Azure Container Registry has an [integrated quarantine feature](https://docs.microsoft.com/azure/container-registry/container-registry-faq#how-do-i-enable-automatic-image-quarantine-for-a-registry) as well that could be considered, however it is in preview at this time.

> :notebook: See [Azure Architecture Center guidance for PCI-DSS 3.2.1 Requirement 6.3.2 in AKS](https://docs.microsoft.com/azure/architecture/reference-architectures/containers/aks-pci/aks-pci-malware#requirement-632).

## Deployment pipelines

Your deployment pipelines are one of the first lines of defense in container image security. Shifting left by introducing build steps like [GitHub Image Scanning](https://github.com/Azure/container-scan) (which leverages common tools like [dockle](https://github.com/goodwithtech/dockle) and [Aquasec trivy](https://github.com/aquasecurity/trivy)) will help ensure that, at build time, your images are linted, CIS benchmarked, and free from known vulnerabilities. You can use any tooling at this step that you trust, including paid, ISV solutions that help provide your desired level of confidence and compliance.

Once your images are built (or identified from a public container registry such as Docker Hub or GitHub Container Registry), the next step is pushing/importing those images to your own container registry. This is the next place a security audit should take place and is in fact the quarantine process identified above. Your newly pushed images undergo any scanning desired. Your pipeline should be gated on the outcome of that scan. If the scan is complete and returned sufficiently healthy results, then your pipeline should move the image into your final container registry repository. If the scan does not complete or is not found sufficiently healthy, you stop that deployment immediately.

## Continuous scanning

The quarantine pattern is ideal for detecting issues with newly pushed images, but _continuous scanning_ is also desirable as CVEs can be found at any time for your images that are in use. **Microsoft Defender for containers** will perform daily scanning of active images and also provide [run-time visibility of vulnerabilities](https://docs.microsoft.com/azure/defender-for-cloud/defender-for-containers-introduction?tabs=defender-for-container-arch-aks#scanning-images-at-runtime) by grouping them and providing details about the issues discovered and how to remediate them. Third party ISV solutions can perform similar tasks. It is recommended that you implement continuous scanning at the registry level. Microsoft Defender for containers currently has limitations with private Azure Container Registry instances (such as yours, exposed exclusively via Private Link). Ensure your continuous scan solution can work within your network restrictions. You may need to bring a third party ISV solution into network adjacency to your container registry to be able to perform your desired scanning. How you react to a CVE (or other issue) detected in your images should be documented in your security operations playbooks. For example, you could remove the image from being available to pull, but that could cause a downstream outage while you're remediating.

## In-cluster scanning

Using a security agent that is container-aware and can operate from within the cluster is another layer of defense, and is the closest to the actual runtime. This should be used to detect threats that were not detectable in an earlier stage, such as reporting on CVE issues on your current running inventory or unexpected runtime behavior. Having an in-cluster runtime security agent be your _only_ issue detection point is _too late_ in the process. These agents come at a cost (compute power, operational complexity, their own security posture), but are often times still considered a valuable addition to your overall defense in depth position. This topic is covered a bit more on the next page.

**Static analysis, registry scanning, and continuous scanning should be the workflow for all of your images; both your own first party and any third party images you use.**

> :notebook: See [Azure Architecture Center guidance for PCI-DSS 3.2.1 Requirement 5 & 6 in AKS](https://docs.microsoft.com/azure/architecture/reference-architectures/containers/aks-pci/aks-pci-malware).

## Steps

1. Quarantine Flux and other public bootstrap security/utility images.

   ```bash
   # Get your Quarantine Azure Container Registry service name
   # You only deployed one ACR instance in this walkthrough, but this could be
   # a separate, dedicated quarantine instance managed by your IT team.
   ACR_NAME_QUARANTINE=$(az deployment group show -g rg-bu0001a0005 -n cluster-stamp --query properties.outputs.quarantineContainerRegistryName.value -o tsv)
   
   # [Combined this takes about eight minutes.]
   az acr import --source ghcr.io/fluxcd/kustomize-controller:v0.8.1 -t quarantine/fluxcd/kustomize-controller:v0.8.1 -n $ACR_NAME_QUARANTINE && \
   az acr import --source ghcr.io/fluxcd/source-controller:v0.8.1 -t quarantine/fluxcd/source-controller:v0.8.1 -n $ACR_NAME_QUARANTINE       && \
   az acr import --source docker.io/falcosecurity/falco:0.29.1 -t quarantine/falcosecurity/falco:0.29.1 -n $ACR_NAME_QUARANTINE               && \
   az acr import --source docker.io/library/busybox:1.33.0 -t quarantine/library/busybox:1.33.0 -n $ACR_NAME_QUARANTINE                       && \
   az acr import --source docker.io/weaveworks/kured:1.9.0 -t quarantine/weaveworks/kured:1.9.0 -n $ACR_NAME_QUARANTINE                       && \
   az acr import --source k8s.gcr.io/ingress-nginx/controller:v1.1.2 -t quarantine/ingress-nginx/controller:v1.1.2 -n $ACR_NAME_QUARANTINE    && \
   az acr import --source docker.io/jettech/kube-webhook-certgen:v1.1.1 -t quarantine/jettech/kube-webhook-certgen:v1.1.1 -n $ACR_NAME_QUARANTINE
   ```

   > The above imports account for 100% of the containers that you are actively bringing to the cluster, but not those that come with the AKS service itself or any of its add-ons. Those images, outside of your direct control, are all sourced from Microsoft Container Registry's (MCR). While you do not have an affordance to inject yourself in the middle of their distribution to your cluster, you can still pull those images through your inspection process for your own audit and reporting purposes. _All container images that you directly bring to the cluster should pass through your quarantine process._ The _allowed images_ Azure Policy associated with this cluster should be configured to match your specific needs. Be sure to update `allowedContainerImagesRegex` in [`cluster-stamp.json`](../../cluster-stamp.json) to define expected image sources to whatever specificity is manageable for you. Never allow a source that you do not intend to use. For example, if you do not bring Open Service Mesh into your cluster, you can remove the existing allowance for `mcr.microsoft.com` as a valid source of images, leaving just `<your acr instance>/live/` repositories as the only valid source for non-system namespaces.

1. Run security audits on images.

   If you had sufficient permissions when we did [subscription configuration](./04-subscription.md), Microsoft Defender for containers is enabled on your subscription. Microsoft Defender for containers will begin [scanning all newly imported images](https://docs.microsoft.com/azure/security-center/defender-for-container-registries-introduction#when-are-images-scanned) in your Azure Container Registry using a Microsoft hosted version of Qualys. The results of those scans will be available in Microsoft Defender for Cloud within 15 minutes. _If Microsoft Defender for containers is not enabled on your subscription, you can skip this step._

   To see the scan results in Microsoft Defender for Cloud, perform the following actions:

   1. Open the [Microsoft Defender for Cloud's **Recommendations** page](https://portal.azure.com/#blade/Microsoft_Azure_Security/SecurityMenuBlade/5).
   1. Under **Controls** expand **Remediate vulnerabilities**.
   1. Click on **Vulnerabilities in Azure Container Registry images should be remediated (powered by Qualys)**.
   1. Expand **Affected resources**.
   1. Click on your ACR instance name under one of the **registries** tabs.

   In here, you can see which container images are **Unhealthy** (had a scan detection), **Healthy** (was scanned, but didn't result in any alerts), and **Unverified** (was unable to be scanned). Unfortunately, Microsoft Defender for containers is [unable to scan all artifacts types](https://docs.microsoft.com/azure/security-center/defender-for-container-registries-introduction#availability). Also, because your container registry is exposed exclusively through Private Link, you won't get a list of those Unverified images listed here. Microsoft Defender for containers is only full-featured with non-network restricted container registries.

   As with any Microsoft Defender for Cloud product, you can set up alerts or via your connected SIEM to be identified when an issue is detected. Periodically checking and discovering security alerts via the Azure Portal is not the expected method to consume these security status notifications. No Microsoft Defender for Cloud alerts are currently configured for this walkthrough.

   **There is no action for you to take, in this step.** This was just a demonstration of Microsoft Defender for Cloud's scanning features. Ultimately, you'll want to build a quarantine pipeline that solves for your needs and aligns with your image deployment strategy and supply chain requirements.

1. Release bootstrap images from quarantine.

   ```bash
   # Get your Azure Container Registry service name
   ACR_NAME=$(az deployment group show -g rg-bu0001a0005 -n cluster-stamp --query properties.outputs.containerRegistryName.value -o tsv)
   
   # [Combined this takes about eight minutes.]
   az acr import --source quarantine/fluxcd/kustomize-controller:v0.8.1 -r $ACR_NAME_QUARANTINE -t live/fluxcd/kustomize-controller:v0.8.1 -n $ACR_NAME && \
   az acr import --source quarantine/fluxcd/source-controller:v0.8.1 -r $ACR_NAME_QUARANTINE -t live/fluxcd/source-controller:v0.8.1 -n $ACR_NAME       && \
   az acr import --source quarantine/falcosecurity/falco:0.29.1 -r $ACR_NAME_QUARANTINE -t live/falcosecurity/falco:0.29.1 -n $ACR_NAME                 && \
   az acr import --source quarantine/library/busybox:1.33.0 -r $ACR_NAME_QUARANTINE -t live/library/busybox:1.33.0 -n $ACR_NAME                         && \
   az acr import --source quarantine/weaveworks/kured:1.9.0 -r $ACR_NAME_QUARANTINE -t live/weaveworks/kured:1.9.0 -n $ACR_NAME                         && \
   az acr import --source quarantine/ingress-nginx/controller:v1.1.2 -r $ACR_NAME_QUARANTINE -t live/ingress-nginx/controller:v1.1.2 -n $ACR_NAME       && \
   az acr import --source quarantine/jettech/kube-webhook-certgen:v1.1.1 -r $ACR_NAME_QUARANTINE -t live/jettech/kube-webhook-certgen:v1.1.1 -n $ACR_NAME
   ```

1. Trigger quarantine violation. _Optional._

   You've deployed an alert called **Image Imported into ACR from source other than approved Quarantine** that will fire if you import an image directly to `live/` without coming from `quarantine/`. If you'd like to see that trigger, go ahead and import an image directly to `live/`. On the validation page later in this walkthrough, you'll see that alert.

   ```bash
   az acr import --source docker.io/library/busybox:1.33.0 -t live/library/busybox:SkippedQuarantine -n $ACR_NAME
   ```

### Next step

:arrow_forward: [Place the cluster under GitOps management](./11-gitops.md)
