# Validate cluster access and boostraping 

Now that your [bootstrapping images have passed through quarantine](./09-pre-cluster-stamp.md) and [the AKS cluster](./10-aks-cluster.md) has been deployed, the next step is to validate cluster access and bootstrapping results.

## Expected results

### Jump box access is validated

Because the cluster is private, your cluster cannot be directly accessed locally. You'll validate controlled jump box access for direct ops against the cluster if needed.

### Bootstrapping results validation

Your cluster was deployed with Azure Policy and the Flux GitOps extension. You'll execute some commands to show how those are manifesting itself in your cluster.

## Steps

1. Connect to a jump box node via Azure Bastion.

   If this is the first time you've used Azure Bastion, here is a detailed walk through of this process.

   1. Open the [Azure Portal](https://portal.azure.com).
   1. Navigate to the **rg-bu0001a0005** resource group.
   1. Click on the Virtual Machine Scale Set resource named **vmss-jumpboxes**.
   1. Click **Instances**.
   1. Click the name of any of the two listed instances. E.g. **vmss-jumpboxes_0**
   1. Click **Connect** -> **Bastion** -> **Use Bastion**.
   1. Fill in the username field with one of the users from your customized `jumpBoxCloudInit.yml` file. E.g. **opsuser01**
   1. Select **SSH Private Key from Local File** and select your private key file (e.g. `opsuser01.key`) for that specific user.
   1. Provide your SSH passphrase in **SSH Passphrase** if your private key is protected with one.
   1. Click **Connect**.
   1. For enhanced "copy-on-select" & "paste-on-right-click" support, your browser may request your permission to support those features. It's recommended that you _Allow_ that feature. If you don't, you'll have to use the **>>** flyout on the screen to perform copy & paste actions.
   1. Welcome to your jump box!

   > :warning: The jump box deployed in this walkthrough has only ephemeral disks attached, in which content written to disk will not survive planned or unplanned restarts of the host. Never store anything of value on these jump boxes. They are expected to be fully ephemeral in nature, and in fact could be scaled-to-zero when not in use.

1. _From your Azure Bastion connection_, log into your Azure RBAC tenant and select your subscription.

   The following command will perform a device login. Ensure you're logging in with the Microsoft Entra user that has access to your AKS resources (i.e. the one you did your deployment with.)

   ```bash
   az login
   # This will give you a link to https://microsoft.com/devicelogin where you can enter 
   # the provided code and perform authentication.

   # Ensure you're on the correct subscription
   az account show

   # If not, select the correct subscription
   # az account set -s <subscription name or id>
   ```

   > :warning: Your organization may have a conditional access policies in place that forbids access to Azure resources [from non corporate-managed devices]https://learn.microsoft.com/entra/identity/conditional-access/concept-conditional-access-grant). This jump box as deployed in these steps might trigger that policy. If that is the case, you'll need to work with your IT Security organization to provide an alterative access mechanism or temporary solution.

1. _From your Azure Bastion connection_, get your AKS credentials and set your `kubectl` context to your cluster.

   ```bash
   AKS_CLUSTER_NAME=$(az deployment group show -g rg-bu0001a0005 -n cluster-stamp --query properties.outputs.aksClusterName.value -o tsv)

   az aks get-credentials -g rg-bu0001a0005 -n $AKS_CLUSTER_NAME
   ```

1. _From your Azure Bastion connection_, test cluster access and authenticate as a cluster admin user.

   The following command will force you to authenticate into your AKS cluster's control plane. This will start yet another device login flow. For this one (**Azure Kubernetes Service Microsoft Entra Client**), log in with a user that is a member of your cluster admin group in the Microsoft Entra tenant you selected to be used for Kubernetes Cluster API RBAC. Also this is where any specified Microsoft Entra Conditional Access policies would take effect if they had been applied, and ideally you would have first used PIM JIT access to be assigned to the admin group. Remember, the identity you log in here with is the identity you're performing cluster control plane (Cluster API) management commands (e.g. `kubectl`) as.

   ```bash
   kubectl get nodes
   ```

   If all is successful you should see something like:

   ```output
   NAME                                  STATUS   ROLES   AGE   VERSION
   aks-npinscope01-26621167-vmss000000   Ready    agent   20m   v1.26.x
   aks-npinscope01-26621167-vmss000001   Ready    agent   20m   v1.26.x
   aks-npooscope01-26621167-vmss000000   Ready    agent   20m   v1.26.x
   aks-npooscope01-26621167-vmss000001   Ready    agent   20m   v1.26.x
   aks-npsystem-26621167-vmss000000      Ready    agent   20m   v1.26.x
   aks-npsystem-26621167-vmss000001      Ready    agent   20m   v1.26.x
   aks-npsystem-26621167-vmss000002      Ready    agent   20m   v1.26.x
   ```

   > :watch: The access tokens obtained in the prior two steps are subject to a Microsoft identity platform TTL (e.g. six hours). If your `az` or `kubectl` commands start erroring out after hours of usage with a message related to permission/authorization, you'll need to re-execute the `az login` and `az aks get-credentials` (overwriting your context) to refresh those tokens.

1. _From your Azure Bastion connection_, confirm admission policies are applied to the AKS cluster.

   Azure Policy was configured in the cluster deployment with a set of starter policies. Your cluster pods will be covered using the [Azure Policy add-on for AKS](https://learn.microsoft.com/azure/aks/use-pod-security-on-azure-policy). Some of these policies might end up in the denial of a specific Kubernetes API request operation to ensure the pod's specification is compliance with your organization's security best practices. Moreover [data is generated by Azure Policy](https://learn.microsoft.com/azure/governance/policy/how-to/get-compliance-data) to assist the app team in the process of assessing the current compliance state of the AKS cluster. You've assign the [Azure Policy for Kubernetes built-in restricted initiative](https://learn.microsoft.com/azure/aks/use-pod-security-on-azure-policy#built-in-policy-initiatives) as well as ten more [built-in individual Azure policies](https://learn.microsoft.com/azure/aks/policy-samples#microsoftcontainerservice) that enforce that pods perform resource requests, define trusted container registries, allow root filesystem access in read-only mode, enforce the usage of internal load balancers, and enforce https-only Kuberentes Ingress objects.

   ```bash
   kubectl get ConstraintTemplate
   ```

   A similar output as the one showed below should be returned

   ```output
   NAME                                     AGE
   k8sazureallowedcapabilities              21m
   k8sazureallowedseccomp                   21m
   … more …
   k8sazureserviceallowedports              21m
   k8sazurevolumetypes                      21m
   ```

1. _From your Azure Bastion connection_, validate bootstrapping.

   Validate that the Flux extension has bootstrapped your cluster.

   ```bash
   kubectl get namespaces
   ```
   
   You should see namespaces created as described your manifest files, such as `a0005-i`.
   
   ```output
   NAME                        STATUS   AGE
   a0005-i                     Active   79m
   a0005-o                     Active   79m
   cluster-baseline-settings   Active   79m
   default                     Active   107m
   falco-system                Active   79m
   flux-system                 Active   87m
   gatekeeper-system           Active   107m
   ingress-nginx               Active   87m
   kube-node-lease             Active   107m
   kube-public                 Active   107m
   kube-system                 Active   107m
   ```

## Configuration needs outside of GitOps

There is a subnet allocated in this reference implementation called `snet-management-agents` specifically for your build agents to perform unattended, "last mile" deployment, and configuration needs for your cluster. There is no compute deployed to that subnet, but typically this is where you'd put in a Virtual Machine Scale Set as a [GitHub Action Self-Hosted Runner](https://docs.github.com/actions/hosting-your-own-runners/about-self-hosted-runners) or [Azure DevOps Self-Hosted Agent Pool](https://learn.microsoft.com/azure/devops/pipelines/agents/scale-set-agents?view=azure-devops). This compute should be a hardened, minimal installation set, and monitored. Just like a jump box, this compute will span two distinct security zones; in this case, unattended, externally managed GitHub Workflow definitions and your cluster.

In summary, there should be a stated objective in your team that routine processes (especially bootstrapping new clusters), are never performed by a human via direct access tools `kubectl` -- _Zero-kubectl starting from Day 0_. Any ad-hoc human interaction with the cluster introduces risk and audit trail concerns. Obviously, live-site issues will require humans to perform out-of-the-norm practices to triage and address critical issues. Reserve your usage of direct access tooling like this for those times.

## GitOps configuration

The GitOps implementation in this reference architecture is _intentionally simplistic_. Flux is configured to simply monitor manifests in ALL namespaces. It doesn't account for concepts like:

* [Multi-tenancy](https://github.com/fluxcd/flux2-multi-tenancy)
* [Private GitHub repos](https://fluxcd.io/docs/components/source/gitrepositories/#ssh-authentication)
* Kustomization [under/overlays](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/#bases-and-overlays)

* Additional flux controllers like Helm. These are explicitly disabled to reduce surface area on the extension in the regulated cluster. Enable only those controllers you need from within the mcFlux_extension resource in your ARM template.

This reference implementation isn't going to dive into the nuances of git manifest organization. A lot of that depends on your namespacing, multi-tenant needs, multi-stage (dev, pre-prod, prod) deployment needs, multi-cluster needs, etc. **The key takeaway here is to ensure that you're managing your Kubernetes resources in a declarative manner with a reconcile loop, to achieve desired state configuration within your cluster.** Ensuring your cluster internally is managed by a single, appropriately-privileged, observable pipeline will aide in compliance. You'll have a git trail that aligns with a log trail from your GitOps toolkit.

## Public dependencies

As with any dependency your cluster or workload has, you'll want to minimize or eliminate your reliance on services in which you do not have an SLO or do not meet your observability/compliance requirements. Your cluster's GitOps operator(s) should **rely on a git repository that satisfies your reliability & compliance requirements**. Consider using a git mirroring approach to bring your cluster dependencies to be "network local" and provide a fault-tolerant syncing mechanism from centralized working repositories (like your organization's GitHub Enterprise private repositories). Following an approach like this will air gap git repositories as an external dependency, at the cost of added complexity.

## Security tooling

While Azure Kubernetes Service, Microsoft Defender for _topic_, and Azure Policy offers a secure platform foundation; the inner workings of your cluster are more of a relationship with you-and-Kubernetes than you-and-Azure. To that end, most customers bring their own security solutions that solve for their specific compliance and organizational requirements within their clusters. They often bring in holistic ISV solutions like [Aqua Security](https://www.aquasec.com/solutions/azure-container-security/), [Prisma Cloud Compute](hhttps://docs.paloaltonetworks.com/prisma/prisma-cloud/prisma-cloud-admin-compute/install/install_kubernetes.html), [StackRox](https://www.stackrox.com/solutions/microsoft-azure-security/), [Sysdig](https://sysdig.com/partners/microsoft-azure/), and/or [Tigera Enterprise](https://www.tigera.io/tigera-products/calico-enterprise/) to name a few. These solutions offer a suite of added security and reporting controls to your platform, but also come with their own licensing and support agreements.

Common features offered in ISV solutions like these:

* File Integrity Monitoring (FIM)
* Container-aware Anti-Virus (AV) solutions
* CVE Detection against admission requests and already executing images
* CVE Detection on Kubernetes configuration
* Advanced network segmentation
* Dangerous runtime container activity detection
* Workload level CIS benchmark reporting
* Managed network isolation and enhanced observability features (such as network flow visualizers)

Your dependency on or choice of in-cluster tooling to achieve your compliance needs cannot be suggested as a "one-size fits all" in this reference implementation. However, as a reminder of the need to solve for these, the Flux bootstrapping above deployed a _placeholder_ FIM and AV solution. **They are not functioning as a real FIM or AV**, simply a visual reminder that you will likely need to bring a suitable solution for compliance concerns.

This reference implementation includes Microsoft Defender for Containers as a solution for helping you secure your containers and runtime environment. Microsoft Defender for Containers, provides [security alerts](https://learn.microsoft.com/azure/defender-for-cloud/alerts-reference#alerts-k8scluster) on the cluster level and on the underlying cluster nodes by monitoring both the API server activity and the behavior of the workloads themselves.   

You can also consider installing third party solutions to supplement Microsoft Defender for Containers as a defense-in-depth strategy. As an example of that, in this reference implementation you also install a very basic deployment of [Falco](https://falco.org/). It is not configured for alerts, nor tuned to any specific needs. It uses the default rules as they were defined when its manifests were generated. This is installed for illustrative purposes, and you're encouraged to evaluate if a third-party solution like Falco is relevant to your situation. If so, in your final implementation, review and tune its deployment to fit your needs (E.g. add custom rules like [CVE detection](https://artifacthub.io/packages/search?ts_query_web=cve&org=falco), [sudo usage](https://artifacthub.io/packages/falco/security-hub/admin-activities), [basic FIM](https://artifacthub.io/packages/falco/security-hub/file-integrity-monitoring), [SSH Connection monitoring](https://artifacthub.io/packages/falco/security-hub/ssh-connections), and [NGINX containment](https://artifacthub.io/packages/falco/security-hub/nginx)). This tooling, _as most security tooling will be_, is **highly privileged within your cluster**. Usually running as DaemonSets with access to the underlying node in a manner that is well beyond any typical workload in your cluster. Remember to consider the runtime compute and networking requirements of your security tooling when sizing your cluster, as these can often be overlooked when initial cluster sizing conversations are happening.

It's worth noting, some customers with regulated workloads are bringing ISV or open-source security solutions to their clusters in addition to Microsoft Defender for Containers for maximum (and/or redundant) compliance coverage. Azure Kubernetes Service is a managed Kubernetes platform, it does not imply that you will exclusively be using Microsoft products/solutions to solve your requirements. For the most part, after the deployment of the infrastructure and some out-of-the-box addons (like Azure Policy, Azure Monitor, Microsoft Entra Workload ID, Open Service Mesh), you're in charge of what you choose to run in your hosted Kubernetes platform. Bring the business and compliance solving solutions you need to the cluster from the [vast and ever-growing Kubernetes and CNCF ecosystem](https://l.cncf.io/?fullscreen=yes).

**You should ensure all necessary tooling and related reporting/alerting is applied as part of your _initial bootstrapping process_ to ensure coverage _immediately_ after cluster creation.**

> :notebook: See [Azure Architecture Center guidance for PCI-DSS 3.2.1 Requirement 5 & 6 in AKS](https://learn.microsoft.com/azure/architecture/reference-architectures/containers/aks-pci/aks-pci-malware).

### Next step

:arrow_forward: [Deploy your workload](./12-workload.md)
