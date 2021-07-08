# Azure Kubernetes Service (AKS) Baseline Cluster for Regulated Workloads

This reference implementation demonstrates the _recommended starting (baseline) infrastructure architecture_ for an [AKS cluster](https://azure.microsoft.com/services/kubernetes-service) that is under regulatory compliance requirements (such as PCI). This implementation builds directly upon the [AKS Baseline Cluster reference implementation](https://github.com/mspnp/aks-secure-baseline) and adds to it additional implementation points that are more commonly seen in regulated environments vs typical "public cloud" consumption patterns.

| 🎓 Foundational Understanding |
|:------------------------------|
| **If you haven't familiarized yourself with the general-purpose [AKS baseline cluster](https://github.com/mspnp/aks-secure-baseline) architecture, you should start there before continuing here.** This architecture rationalizes and is constructed from the AKS baseline, which is the foundation for this body of work. This reference implementation avoids rearticulating points that are already addressed in the AKS baseline cluster. |

## Compliance

| :warning: | These artifacts have not been certified in any official capacity; regulatory compliance is a _shared responsibility_ between you and your hosting provider. This implementation is designed to aide you on your journey to achieving your compliance, but by itself _does not ensure any level of compliance_. To understand Azure compliance and shared responsibility models, visit the [Microsoft Trust Center](https://www.microsoft.com/trust-center/compliance/compliance-overview). |
|-----------|:--------------------------|

Azure and AKS are well positioned to give you the tools and allow you to build processes necessary to help you achieve a compliant hosting infrastructure. The implementation details can be complex, as is the overall process of compliance. We walk through the deployment here in a rather _verbose_ method to help you understand each component of this architecture, teaching you about each layer and providing you with the knowledge necessary to apply it to your unique compliance scoped workload.

Even if you are not in a regulated environment, this infrastructure demonstrates an AKS cluster with a more heightened security posture over the general-purpose cluster presented in the AKS baseline. You might find it useful to take select concepts from here and apply it to your non-regulated workloads (at the tradeoff of added complexity and hosting costs).

## Azure Architecture Center guidance

This project has a companion set of articles that describe challenges, design patterns, and best practices for a AKS cluster designed to host workloads that fall in **PCI-DSS 3.2.1** scope. You can find this article on the Azure Architecture Center at [Azure Kubernetes Service (AKS) regulated cluster for PCI-DSS 3.2.1](https://aka.ms/architecture/aks-baseline-regulated). If you haven't reviewed it, we suggest you read it; as it will give added context to the considerations applied in this implementation.

## Architecture

**This reference implementation is _infrastructure focused, more so than workload_.** It concentrates on compliance concerns dealing with the AKS cluster itself. This implementation will touch on workload concerns, but does not contain end-to-end guidance on in-scope workload architecture, container security, or isolation. There are some good practices demonstrated and others talked about, but it is not exhaustive.

The implementation presented here is the _minimum starting point for most AKS clusters falling into a compliance scope_. This implementation integrates with Azure services that will deliver observability, provide a network topology that will support public traffic isolation, and keep the in-cluster traffic secure as well. This architecture should be considered your architectural starting point for pre-production and production stages of clusters hosting regulated workloads.

The material here is relatively dense. We strongly encourage you to dedicate _at least four hours_ to walk through these instructions, with a mind to learning. You will not find any "one click" deployment here. However, once you've understood the components involved and identified the shared responsibilities between your team and your greater IT organization, it is encouraged that you build auditable deployment processes around your final infrastructure.

Finally, this implementation uses a small, custom application as an example workload. This workload is minimally interesting, as it is here exclusively to help you experience the infrastructure and illustrate network and security controls in place. The workload, and its deployment, does not represent any sort of "best practices" for regulated workloads.

### Core architecture components

#### Azure platform

* AKS v1.20
  * System and User [node pool separation](https://docs.microsoft.com/azure/aks/use-system-pools)
  * [AKS-managed Azure AD](https://docs.microsoft.com/azure/aks/managed-aad)
  * Managed Identities for kubelet and control plane
  * Azure CNI
  * [Azure Monitor for containers](https://docs.microsoft.com/azure/azure-monitor/insights/container-insights-overview)
  * Private Cluster (Kubernetes API Server)
  * [Azure AD Pod Identity](https://docs.microsoft.com/azure/aks/use-azure-ad-pod-identity)
* Azure Virtual Networks (hub-spoke)
  * Azure Firewall managed egress
  * Hub-proxied DNS
  * BYO Private DNS Zone for AKS
* Azure Application Gateway (WAF - OWASP 3.1)
* AKS-managed Internal Load Balancers
* Azure Bastion for maintenance access
* Private Link enabled Key Vault and Azure Container Registry
* Private Azure Container Registry Task Runners

#### In-cluster Open-Source Software components

* [Secrets Store CSI Driver for Kubernetes](https://docs.microsoft.com/azure/aks/csi-secrets-store-driver)
* [Falco](https://falco.org)
* [Flux 2 GitOps Operator](https://fluxcd.io)
* [Kured](https://docs.microsoft.com/azure/aks/node-updates-kured)
* [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
* [Open Service Mesh](https://openservicemesh.io/)

#### Network topology

![Network diagram depicting a hub-spoke network with two peered VNets. The cluster spoke contains subnets for a jump box, the cluster, and other related services.](/networking/network-topology.svg)

#### Workload HTTPS request flow

![Network flow showing Internet traffic passing through Azure Application Gateway then into the Ingress Controller and then through the workload pods. All connections are TLS.](/docs/flow.svg)

## Deploy the reference implementation

A deployment of AKS-hosted workloads typically experiences a separation of duties and lifecycle management in the area of identity & security group management, the host network, the cluster infrastructure, and finally the workload itself. This reference implementation will have you be working across these various roles. Regulated environments require strong, documented separation of concerns; but ultimately you'll decide where each boundary should be.

Also, please remember the primary purpose of this body of work is to illustrate the topology and decisions made in this cluster. A guided, "step-by-step" flow will help you learn the pieces of the solution and give you insight into the relationship between them. A bedrock understanding of your infrastructure, its supply chain, and its "Day-2" workflows are critical for compliance concerns. If you cannot explain each decision point and rationalization, audit conversations can quickly turn uncomfortable.

Ultimately, lifecycle/SDLC management of your cluster, its dependencies, and your workloads will depend on your specific situation. You'll need to account for team roles, centralized & decentralized IT roles, organizational standards, industry expectations, and specific mandates by your compliance auditor.

**Please start this learning journey in the _Prepare the subscription_ section.** If you follow this through the end, you'll have our recommended baseline cluster for regulated industries installed, with a sample workload running for you to reference in your own Azure subscription.

### 1. :rocket: Prepare the subscription

There are considerations that must be addressed before you start deploying your cluster. Do I have enough permissions in my subscription and AD tenant to do a deployment of this size? How much of this will be handled by my team directly vs having another team be responsible?

* [ ] Begin by ensuring you [install and meet the prerequisites](./docs/deploy/01-prerequisites.md).
* [ ] [Procure required TLS certificates](./docs/deploy/02-ca-certificates.md).
* [ ] Plan your [Azure Active Directory integration](./docs/deploy/03-aad.md).
* [ ] [Apply Azure Policy and Azure Defender configuration](./docs/deploy/04-subscription.md) to your target subscription.

### 2. Build regional networking hub

This reference implementation is built on a traditional hub-spoke model, typical found in your organization's _Connectivity_ subscription. The hub will contain Azure Firewall, DNS forwarder, and Azure Bastion services.

* [ ] [Build the regional hub](./docs/deploy/05-networking-hub.md) to control and monitor spoke traffic.

### 3. Plan Kubernetes API server access

Because the AKS server is a "private cluster" the control plane is not exposed to the internet. Management now can only be performed with network line of sight to the private endpoint exposed by AKS. In this case, you'll build a Azure Bastion-fronted jump box.

* [ ] [Build cluster operations VM image](./docs/deploy/06-aks-jumpboximage.md) in an isolated network spoke.
* [ ] [Build cloud-init configuration](./docs/deploy/07-aks-jumpbox-users.md) for the operations VM image.

### 4. Deploy the cluster

Deploy the Azure resources that make up the primary runtime components of this architecture; the AKS cluster itself, jump box, Azure Container Registry, Azure Application Gateway, and Azure Key Vault.

* [ ] [Deploy the target network spoke](./docs/deploy/08-cluster-networking.md) that the cluster will be homed to.
* [ ] [Deploy the AKS cluster](./docs/deploy/09-aks-cluster.md) and supporting services.

#### and then bootstrap it

Bootstrapping your cluster should be seen as a direct _immediate follow_ of deploying any cluster. This takes the raw AKS cluster and enrolls it in GitOps which will adds workload-agnostic baseline functionality (such as security agents).

* [ ] [Quarantine & import all bootstrap images](./docs/deploy/10-pre-bootstrap.md) to Azure Container Registry.
* [ ] [Place the cluster under GitOps management](./docs/deploy/11-gitops.md).

### 5. Deploy your workload

A simple workload made up of four interconnected services is manually deployed across two namespaces to illustrate concepts such as nodepool placement, zero-trust network policies, and external infrastructure protections offered by the applied NSGs and Azure Firewall rules.

* [ ] [Deploy the workload](./docs/deploy/12-workload.md).

### 6. :checkered_flag: Validation

Now that the cluster and the sample workload is deployed; now it's time to look at how the cluster is functioning.

* [ ] [Perform end-to-end deployment validation](./docs/deploy/13-validation.md).
* [ ] [Review resource logs & Azure Security Center data](./docs/deploy/13-validation-logs.md)

### 7. :broom: Clean up resources

Most of the Azure resources deployed in the prior steps will have ongoing billing impact unless removed.

* [ ] [Cleanup all resources](./docs/deploy/14-cleanup.md)

## Separation of duties

All workloads that find themselves in compliance scope usually require a documented separation of duties/concern implementation plan. Kubernetes poses an interesting challenge in that it involves a significant number of roles typically found across an IT organization. Networking, identity, SecOps, governance, workload teams, cluster operations, deployment pipelines, any many more. If you're looking for a starting point on how you might consider breaking up the roles that are adjacent to the AKS cluster, consider **reviewing our [Azure AD role guide](./docs/rbac-suggestions.md)** shipped as part of this reference implementation.

## Is that all, what about … !?

Yes, there are concerns that do extend beyond what this implementation could reasonably demonstrate for a general audience. This reference implementation strived to be accessible for most people without putting undo burdens on the subscription brought to this walkthrough. This means SKU choices with relatively large default quotas, not using features that have very limited regional availability, not asking for learners to be overwhelmed with "Bring your own encryption key" options for services, and similar. All in hopes that more people can complete this walkthrough without disruption or excessive coordination with subscription or management group owners.

For your implementation, take this starting point and please add on additional security measures talked about throughout the walkthrough that were not directly implemented. For example, enable JIT and Conditional Access Policies, leverage Encryption-at-Host features if applicable to your workload, etc.

**For a list of additional considerations for your architecture, please see our [Additional Considerations](./docs/additional-considerations.md) document.**

## Cost

This reference implementation runs idle around $95 (US Dollars) per day within the first 30 days; and you can expect it to increase over time as some Security Center tooling has free-trial period and logs will continue to accrue. The largest contributors to the starting cost are Azure Firewall, the AKS nodepools (VM Scale Sets), and Log Analytics. While some costs are usually cluster operator costs, such as nodepool VMSS, log analytics, incremental Azure Defender costs; others will likely be amortized across multiple business units and/or applications, such as Azure Firewall.

While some customers will amortize cluster costs across workloads by hosting a multi-tenant cluster within their organization, maximizing density with workload diversity, doing so with regulated workloads is not advised. Regulated environments will generally prioritize compliance and security (isolation) over cost (diverse density).

## Final thoughts

Kubernetes is a very flexible platform, giving infrastructure and application operators many choices to achieve their business and technology objectives. At points along your journey, you will need to consider when to take dependencies on Azure platform features, CNCF OSS solutions, ISV solutions, support channels, and what operational processes need to be in place. **We encourage this reference implementation to be the place you _start_ architectural conversations within your own team; adapting to your specific requirements, and ultimately delivering a solution that delights your customers and your auditors.**

## Related documentation

* [Azure Kubernetes Service Baseline Architecture](https://aka.ms/architecture/aks-baseline)
* [Azure Kubernetes Service Documentation](https://docs.microsoft.com/azure/aks/)
* [Microsoft Azure Well-Architected Framework](https://docs.microsoft.com/azure/architecture/framework/)
* [Microservices architecture on AKS](https://docs.microsoft.com/azure/architecture/reference-architectures/containers/aks-microservices/aks-microservices)

## Contributions

Please see our [contributor guide](./CONTRIBUTING.md).

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact <opencode@microsoft.com> with any additional questions or comments.

With :heart: from Microsoft Patterns & Practices, [Azure Architecture Center](https://aka.ms/architecture).
