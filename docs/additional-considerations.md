# Additional Considerations

This reference implementation is designed to be a starting point for your eventual architecture. It does not enable "every security option possible." While some of the features that are not enabled we'd encourage their usage, practicality supporting high completion rate of this material prevents the enablement of some feature. For example, your subscription permissions, already existing security policies in the subscription, existing policies that might block deployment, simplicity in demonstration, etc. Not all going through this walkthrough have the luxury of exploring it in a situation where they are subscription owner and Azure AD administrator. Because they were not trivial to deploy in this walkthrough, we wanted to ensure you at least have a list of things we'd have liked to include out of the box or at least have introduced as a consideration. Review these and add them into your final architecture as you see fit.

In addition to the ones mentioned below, the [Azure Architecture Center guidance for PCI-DSS 3.2.1 with AKS](https://docs.microsoft.com/azure/architecture/reference-architectures/containers/aks-pci/aks-pci-intro) also includes sepcific recommendations that might not be implemented in this solution. Some of those will be called out below.

## Host/disk encryption

<details>
  <summary>View considerations…</summary>

### Customer-managed OS and data disk encryption

While OS and data disks (and their caches) are already encrypted at rest with Microsoft-managed keys, for additional control over encryption keys you can use customer-managed keys for encryption at rest for both the OS and the data disks in your AKS cluster. This reference implementation doesn't actually use any disks in the cluster, and the OS disk is ephemeral.

> :notebook: See the [Azure Architecture Center PCI-DSS 3.2.1 Disc encryption article](https://docs.microsoft.com/azure/architecture/reference-architectures/containers/aks-pci/aks-pci-ra-code-assets#disk-encryption).

Note, we enable an Azure Policy alert detecting clusters without this feature enabled. The reference implementation will trip this policy alert because there is no `diskEncryptionSetID` provided on the cluster resource. The policy is in place as a reminder of this security feature that you might wish to use. The policy is set to "audit" not "block."

### Host-based encryption

You can take OS and data disk encryption one step further and also bring the encryption up to the Azure host. Using [Host-Based Encryption](https://docs.microsoft.com/azure/aks/enable-host-encryption) means that the temp disks now will be encrypted at rest using platform-managed keys. This will then cover encryption of the VMSS ephemeral OS disk and temp disks.

> :notebook: See the Azure Architecture Center PCI-DSS 3.2.1 for AKS [Disc encryption article](https://docs.microsoft.com/azure/architecture/reference-architectures/containers/aks-pci/aks-pci-ra-code-assets#disk-encryption).

Note, like above, we enable an Azure Policy detecting clusters without this feature enabled. The reference implementation will trip this policy alert because this feature is not enabled on the `agentPoolProfiles`. The policy is in place as a reminder of this security feature that you might wish to use once it is GA. The policy is set to "audit" not "block."

</details>

## Networking

<details>
  <summary>View considerations…</summary>

### Enable Network Watcher and Traffic Analytics

Observability into your network is critical for compliance. [Network Watcher](https://docs.microsoft.com/azure/network-watcher/network-watcher-monitoring-overview), combined with [Traffic Analytics](https://docs.microsoft.com/azure/network-watcher/traffic-analytics) will help provide a perspective into traffic traversing your networks. This reference implementation will _attempt_ to deploy NSG Flow Logs and Traffic Analytics. These features depend on a regional Network Watcher resource being installed on your subscription. Network Watchers are singletons in a subscription, and their creation is _usually_ automatic and  might exist in a resource group you do not have RBAC access to. We strongly encourage you to enable [NSG flow logs](https://docs.microsoft.com/azure/network-watcher/network-watcher-nsg-flow-logging-overview) on your AKS Cluster subnets, build agent subnets, Azure Application Gateway, and other subnets that may be a source of traffic into and out of your cluster. Ensure you're sending your NSG Flow Logs to a **V2 Storage Account** and set your retention period in the Storage Account for these logs to a value that is at least as long as your compliance needs (e.g. 90 days).

In addition to Network Watcher aiding in compliance considerations, it's also a highly valuable network troubleshooting utility. As your network is private and heavy with flow restrictions, troubleshooting network flow issues can be time consuming. Network Watcher can help provide additional insight when other troubleshooting means are not sufficient.

As an added measure use apply the [Flow logs should be enabled for every network security group](https://portal.azure.com/#blade/Microsoft_Azure_Policy/PolicyDetailBlade/definitionId/%2Fproviders%2FMicrosoft.Authorization%2FpolicyDefinitions%2F27960feb-a23c-4577-8d36-ef8b5f35e0be) Azure Policy at the Subscription or Management Group level.

### More strict Network Security Groups (NSGs)

> :notebook: See the Azure Architecture Center PCI-DSS 3.2.1 for AKS [Subnet security through NSGs article](https://docs.microsoft.com/azure/architecture/reference-architectures/containers/aks-pci/aks-pci-ra-code-assets#subnet-security-through-network-security-groups-nsgs).

### Azure Key Vault network restrictions

> :notebook: See the Azure Architecture Center PCI-DSS 3.2.1 for AKS [Azure Key Vault network restrictions article](https://docs.microsoft.com/azure/architecture/reference-architectures/containers/aks-pci/aks-pci-ra-code-assets#azure-key-vault-network-restrictions).


### Expanded NetworkPolicies

Not all user-provided namespaces in this reference implementation employ a zero-trust network. For example `cluster-baseline-settings` does not. We provide an example of zero-trust networks in `a0005-i` and `a0005-o` as your reference implementation of the concept. All namespaces (other than `kube-system`, `gatekeeper-system`, and other AKS-provided namespaces) should have a maximally restrictive NetworkPolicy applied. What those policies will be will be based on the pods running in those namespaces. Ensure your accounting for readiness, liveliness, and startup probes and also accounting for metrics gathering by `oms-agent`.  Consider standardizing on ports across your workloads so that you can provide a consistent NetworkPolicy and even Azure Policy for allowed container ports.

### Enable DDoS Protection

> :notebook: See the Azure Architecture Center PCI-DSS 3.2.1 for AKS [DDoS protection article](https://docs.microsoft.com/azure/architecture/reference-architectures/containers/aks-pci/aks-pci-ra-code-assets#ddos-protection).


</details>

## Secure Pod definitions

<details>
  <summary>View considerations…</summary>

### Make use of container securityContext options

When describing your workload's security needs, leverage all relevant [`securityContext` settings](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/) for your containers. The workloads deployed in this reference implementation do NOT represent best practices, as this reference implementation was mainly infrastructure focused.

> :notebook: See the Azure Architecture Center PCI-DSS 3.2.1 for AKS [Pod security article](https://docs.microsoft.com/azure/architecture/reference-architectures/containers/aks-pci/aks-pci-ra-code-assets#pod-security).

### Pin image versions

When practical to do so, do not reference images by their tags in your deployment manifests, this includes version tags like `1.0` and certinally never mutable tags like `latest`. While it may be verbose to do, prefer referring images with their actual image id; for example `my-image:@sha256:10f9714876074e25bdae42bc9ed6fde9a7758706-09fa-474c-86bd-eb7a95ae21ec`. This will ensures you can reliably map container scan results with the actual content running in your cluster.

You can extend the Azure Policy for image name to include this pattern in the allowed regular expression to help enforce this.

This guidance should also be followed when using the Dockerfile `FROM` command.

</details>

## Azure Policy

<details>
  <summary>View considerations…</summary>

### Customized Azure Policies for AKS

> :notebook: See the Azure Architecture Center PCI-DSS 3.2.1 for AKS [Azure Policy considerations article](https://docs.microsoft.com/azure/architecture/reference-architectures/containers/aks-pci/aks-pci-ra-code-assets#azure-policy-considerations).

### Customized Azure Policies for Azure resources

The reference implementation includes a few examples of Azure Policy that can act to help guard your environment against undesired configuration. One such example included in this reference implementation is the preventing of Network Interfaces or VM Scale Sales that have Public IPs from joining your cluster's Virtual Network. It's strongly recommended that you add prevents (deny-based policy) for resource configuration that would violate your regulatory requirements. If a built-in policy is not available, create custom policies like the ones illustrated in this reference implementation.

### Allow list for resource types

The reference implementation puts in place an allow list for what resource types are allowed in the various resource groups. This helps control what gets deployed, which can prevent an unexpected resource type from being deployed. If your subscription is exclusively for your regulated workload, then also consider only having the necessary [resource providers registered](https://docs.microsoft.com/azure/azure-resource-manager/management/azure-services-resource-providers#registration) to cover that service list. Don't register [resource providers for Azure services](https://docs.microsoft.com/azure/azure-resource-manager/management/azure-services-resource-providers) that are not going to be part of your environment. This will guard against a misconfiguration in Azure Policy's enforcement.

### Management Groups

This reference implementation is expected to be deployed in a standalone subscription.  As such, Azure Policies are applied at a relatively local scope (subscription or resource group). If you have multiple subscriptions that will be under regulatory compliance, consider grouping them under a [management group hierarchy](https://docs.microsoft.com/azure/cloud-adoption-framework/ready/enterprise-scale/management-group-and-subscription-organization) that applies the relevant Azure Policies uniformly across your in-scope subscriptions.

</details>

## Microsoft Defender for Cloud

<details>
  <summary>View considerations…</summary>

### Enterprise onboarding to Microsoft Defender for Cloud

> :notebook: See the Azure Architecture Center PCI-DSS 3.2.1 for AKS [Security monitoring article](https://docs.microsoft.com/azure/architecture/reference-architectures/containers/aks-pci/aks-pci-ra-code-assets#security-monitoring).

### Create triage process for alerts

From the [Security alerts view](https://portal.azure.com/#blade/Microsoft_Azure_Security/SecurityMenuBlade/7) in Microsoft Defender for Cloud (or via Azure Resource Graph), you have access to all alerts that Microsoft Defender for Cloud detects on your resources. You should have a triage process in place address or defer detected issues. Work with your security team to understand how relevant alerts will be made available to the workload owner(s).

</details>

## Container registry

<details>
  <summary>View considerations…</summary>

### OCI Artifact Signing

Azure Container Registry supports the [signing of images](https://docs.microsoft.com/azure/container-registry/container-registry-content-trust), built on [CNFC Notary (v1)](https://github.com/theupdateframework/notary). This, coupled with an admission controller that supports validating signatures, can ensure that you're only running images that you've signed with your private keys. This integration is not something that is provided, today, end-to-end by Azure Container Registry and AKS (Azure Policy), and can consider bringing open source solutions like [SSE Connaisseur](https://github.com/sse-secure-systems/connaisseur) or [IBM Portieris](https://github.com/IBM/portieris). A working group in the CNFC is currently working on [Notary v2](https://github.com/notaryproject/notaryproject) for signing OCI Artifacts (i.e. container images and helm charts), and both the ACR and AKS roadmap includes adding a more native end-to-end experience in this space built upon this foundation.

### Customer-managed encryption

While container images and other OCI artifacts typically do not contain sensitive data, they do typically contain your Intellectual Property. Use customer-managed keys to manage the encryption at rest of the contents of your registries. By default, the data is encrypted at rest with service-managed keys, but customer-managed keys are sometimes required to meet regulatory compliance standards. Customer-managed keys enable the data to be encrypted with an Azure Key Vault key created and owned by you. You have full control and _responsibility_ for the key lifecycle, including rotation and management. Learn more at, [Encrypt registry using a customer-managed key](https://aka.ms/acr/CMK).

</details>

## Authentication & Authorization

<details>
  <summary>View considerations…</summary>

### JIT and Conditional Access Policies

> :notebook: See [Azure Architecture Center guidance for PCI-DSS 3.2.1 Requirement 7.2.1 in AKS](https://docs.microsoft.com/azure/architecture/reference-architectures/containers/aks-pci/aks-pci-identity#requirement-721) and this repo's [Azure AD Conditional Access](./conditional-access.md) page.

### Custom Cluster Roles

Regulatory compliance often requires well defined roles, with specific access policies associated with that role. If one person fills multiple roles, they should be assigned the roles that are relevant to all of their job titles. This reference implementation doesn't demonstrate any specific role structure, and matter of fact, everything you did throughout this walkthrough was done with the most privileged role in the cluster. Part of your compliance work must be to define roles and map them allowed Kubernetes actions, scoped as narrow as practical. Even if one person is directly responsible for both the cluster and the workload, craft your Kubernetes ClusterRoles as if there were separate individuals, and then assign that single individual all relevant roles. Minimize any "do it all" roles, and favor role composition to achieve management at scale.

</details>

## Image building

<details>
  <summary>View considerations…</summary>

### Use "distroless" images

Where your workload supports it, always prefer the usage of "distroless" base images for your workloads. These are specially crafted base images that minimize the potential security surface area of your images by removing ancillary features (shells, package managers, etc.) that are not relevant to your workload. Doing so should, generally speaking, reduce CVE hit rates. Every detected CVE in your images should kick off your defined triage process, which is an expensive, human-driven task that benefits from having an improved signal-to-noise ratio.

</details>

## Kubernetes API Server access

<details>
  <summary>View considerations…</summary>

### Live-site cluster access alternatives

If you wish to add an auditable layer of indirection between cluster & application administrators and the cluster for live-site issues, you might consider a ChatOps approach, in which commands against the cluster are executed by dedicated, hardened compute in a subnet like the one above for deployment but are fronted by a Microsoft Teams integration. That gives you the ability to _limit commands_ executed against the cluster, without necessarily building an ops process based exclusively around jump boxes. Also, you may already have an IAM-gated IT automation platform in place in which pre-defined _actions_ can be constructed within. Its action runners would then execute within the `snet-management-agents` subnet while the initial invocation of the actions is audited and controlled in the IT automation platform.

### Build Agents

Pipeline agents should be run external to your regulated cluster. While it is possible to do that work on the cluster itself, providing a clear separation of concerns is vital. The build process itself is a potential threat vector and executing that processes as a cluster workload is inappropriate. If you wish to use Kubernetes as your build agent infrastructure, that's fine; just _do not co-mingle that process with your regulated workload runtime_.

Your build agents should be as air-gapped as practical from your cluster, reserving your agents exclusively for last mile interaction with the Kubernetes API Server (if that's how you do your deployments). If instead your build agents can be completely disconnected from your cluster and instead needing just network line of sight to Azure Container Registry to push container images, helm charts, etc and then GitOps does the deployment, even better. Strive for a build and publish workflow that minimizes or eliminates any direct need for network line of sight to your Kubernetes Cluster API (or its nodes).

</details>

## Security Alerts

<details>
  <summary>View considerations…</summary>

### Microsoft's Security Response Center

Inline, we talked about many ISV's security agents being able to detect relevant CVEs for your cluster and workloads. But in addition to relying on tooling, you can also see [Microsoft's Security Response Center's 1st-party CVE listings](https://msrc.microsoft.com/update-guide/vulnerability) at any time. Here's [CVE-2021-27075](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2021-27075), an Information Disclosure entry from March 2021 as an example. No matter how you keep yourself informed about current CVEs, ensure you have a documented plan to stay informed.

### Microsoft Sentinel

Microsoft Sentinel was enabled in this reference implementation. No alerts were created or any sort of "usage" of it, other than enabling it. You may already be using another SIEM, likewise you may find that a SIEM is not cost effective for your solution. Evaluate if you will derive benefit from Microsoft Sentinel in your solution, and tune as needed.

> :notebook: See [Azure Architecture Center guidance for PCI-DSS 3.2.1 Requirement 10.5 in AKS](https://docs.microsoft.com/azure/architecture/reference-architectures/containers/aks-pci/aks-pci-monitor#requirement-105)

</details>

## Disaster Recovery

<details>
  <summary>View considerations…</summary>

### Cluster Backups (State and Resources)

While we generally discourage any storage of state within a cluster, you may find your workload demands in-cluster storage. Regardless if that data is in compliance scope or not, you'll often require a robust and secure process for backup and recovery. You may find a solution like Azure Backup (for Azure Disks and Azure Files), [Veeam Kasten K10](https://kasten.io), or [VMware Velero](https://velero.io/) instrumental in achieving any `PersistantVolumeClaim` backup and recovery strategies.

All backup process needs to classify the data contained within the backup. This is true of data both within and external to your cluster. If the data falls within regulatory scope, you'll need extend your compliance boundaries to the lifecycle and destination of the backup -- which will be outside of the cluster. Consider geographic restrictions, encryption at rest, access controls, roles and responsibilities, auditing, time-to-live, and tampering prevention (check-sums, etc) when designing your backup system. Backups can be a vector for malicious intent, with a bad actor compromising a backup and then forcing an event in which their backup is restored.

> :notebook: See the Azure Architecture Center PCI-DSS 3.2.1 for AKS [Cluster backups (state and resources) article](https://docs.microsoft.com/azure/architecture/reference-architectures/containers/aks-pci/aks-pci-ra-code-assets#cluster-backups-state-and-resources).

</details>

## TLS

<details>
  <summary>View considerations…</summary>

### mTLS Certificate Provider Choice

While this reference implementation uses Tresor as its TLS certificate provider for mesh communication, you may wish to use a more formal certificate provider for your mTLS implementation (if you choose to implement mTLS). You may wish to use CertManager, HashiCorp Vault, Key Vault, or even your own internal certificate provider. If you use a mesh, ensure its compatible with your certificate provider of choice.

### Ingress Controller

The ingress controller implemented in this reference implementation is relatively simplistic in implementation. It's currently using a wildcard certificate to handle default traffic when an `Ingress` resource doesn't contain a specific certificate. This might be fine for most customers, but if you have an organizational policy against using wildcard certs (even on your internal, private network), you may need to adjust your ingress controller to not support a "default certificate" and instead require ever workload to surface their own named certificate. This will impact how Azure Application Gateway is performing backend health checks.

</details>

## Logging

<details>
  <summary>View considerations…</summary>

### Tuning the Log Analytics Agent in your cluster

The in-cluster `omsagent` pods running in `kube-system` are the Log Analytics collection agent. They are responsible for gathering telemetry, scraping container `stdout` and `stderr` logs, and collecting Prometheus metrics. You can tune its collection settings by updating the [`container-azm-ms-agentconfig.yaml`](/cluster-manifests/kube-system/container-azm-ms-agentconfig.yaml) ConfigMap file. In this reference implementation, logging is enabled across `kube-system` and all your workloads. By default, `kube-system` is excluded from logging. Ensure you're adjusting the log collection process to achieve balance cost objectives, SRE efficiency when reviewing logs, and compliance needs.

### Retention and continous export

> :notebook: See the Azure Architecture Center PCI-DSS 3.2.1 for AKS [Security monitoring article](https://docs.microsoft.com/azure/architecture/reference-architectures/containers/aks-pci/aks-pci-ra-code-assets#security-monitoring).

</details>

## Next step

:arrow_forward: [Back to main README](/README.md#is-that-all-what-about--)
