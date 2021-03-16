# Azure Kubernetes Service (AKS) Baseline Cluster for Regulated Industries

This reference implementation demonstrates the _recommended starting (baseline) infrastructure architecture_ for an [AKS cluster](https://azure.microsoft.com/services/kubernetes-service) that is under regulatory compliance requirements (such as PCI). This implementation builds upon the [AKS Baseline Cluster reference implementation](https://github.com/mspnp/aks-secure-baseline) and adds to it additional implementation points that are more commonly seen in regulated environments vs typical "public cloud" consumption patterns. **If you haven't familiarized yourself with the general-purpose [AKS baseline cluster](https://github.com/mspnp/aks-secure-baseline), you should strongly consider starting there before continuing here.**

> :warning: **These artifacts have not been certified in any official capacity; regulatory compliance is a shared responsibility between you and your hosting provider.** This implementation is designed to aide you on your journey to achieving your compliance, but by itself does not ensure any level of compliance.

AKS is well positioned to give you the tools and processes necessary to help you achieve a compliant hosting infrastructure. The implementation details can be complex, as is the overall process of compliance. We walk through the deployment here in a rather _verbose_ method to help you understand each component of this cluster, ideally teaching you about each layer and providing you with the knowledge necessary to apply it to your unique compliance scoped workload.

Even if you are not in a regulated environment, this infrastructure will show a more heightened security posture cluster than the general-purpose cluster presented in the baseline, and you might find it useful to take select concepts from here and apply it to your non-regulated workloads as added security (at the tradeoff of added complexity and hosting costs).

## Azure Architecture Center guidance

This project has a companion set of articles that describe challenges, design patterns, and best practices for a AKS cluster designed to host workloads that fall in regulatory scope. You can find this article on the Azure Architecture Center at [Azure Kubernetes Service (AKS) Baseline Cluster for Regulated Industries](https://aka.ms/architecture/aks-baseline-regulated). If you haven't reviewed it, we suggest you read it as it will give added context to the considerations applied in this implementation. Ultimately, this is the direct implementation of that specific architectural guidance.

## Architecture

**This reference implementation is infrastructure focused**, more so than workload. It concentrates on the AKS cluster itself, including concerns with identity, post-deployment configuration, secret management, and network topologies. Where it touches on workload is around in-cluster policies that are typical of regulated workload concerns.

The implementation presented here is the _minimum recommended baseline for most AKS clusters falling into a regulated scope_. This implementation integrates with Azure services that will deliver observability, provide a network topology that will support multi-regional growth, and keep the in-cluster traffic secure as well. This architecture should be considered your starting point for pre-production and production stages of clusters hosting regulated workloads.

The material here is relatively dense. We strongly encourage you to dedicate time to walk through these instructions, with a mind to learning. We do NOT provide any "one click" deployment here. However, once you've understood the components involved and identified the shared responsibilities between your team and your great organization, it is encouraged that you build suitable, auditable deployment processes around your final infrastructure.

Finally, this implementation uses a small custom application as an example workload. This workload is minimally interesting, as it is here exclusively to help you experience the infrastructure and illustrate network and security controls in place. We'll introduce the workload in more detail later in the instructions.

### Core architecture components

#### Azure platform

* AKS v1.20
  * System and User [node pool separation](https://docs.microsoft.com/azure/aks/use-system-pools)
  * [AKS-managed Azure AD](https://docs.microsoft.com/azure/aks/managed-aad)
  * Managed Identities for kubelet and control plane
  * Azure CNI
  * [Azure Monitor for containers](https://docs.microsoft.com/azure/azure-monitor/insights/container-insights-overview)
  * Private Cluster
  * [Azure AD Pod Identity](https://github.com/Azure/aad-pod-identity)
* Azure Virtual Networks (hub-spoke)
  * Hub-proxied DNS
  * Azure Firewall managed egress
* Azure Application Gateway (WAF - OWASP 3.1)
* AKS-managed Internal Load Balancers
* Azure Bastion for maintenance access
* Private Link enabled Key Vault and Azure Container Registry
* Private Azure Container Registry Task Runners

#### In-cluster Open-Source Software components

* [Flux 2 GitOps Operator](https://fluxcd.io)
* [Traefik Ingress Controller](https://doc.traefik.io/traefik/v1.7/user-guide/kubernetes/)
* [Azure KeyVault Secret Store CSI Provider](https://github.com/Azure/secrets-store-csi-driver-provider-azure)
* [Kured](https://docs.microsoft.com/azure/aks/node-updates-kured)
* [Falco](https://falco.org)

![Network diagram depicting a hub-spoke network with two peered VNets, each with three subnets and main Azure resources.](https://docs.microsoft.com/azure/architecture/reference-architectures/containers/aks/images/secure-baseline-architecture.svg)

## Deploy the reference implementation

A deployment of AKS-hosted workloads typically experiences a separation of duties and lifecycle management in the area of prerequisites, the host network, the cluster infrastructure, and finally the workload itself. This reference implementation is similar. Also, be aware our primary purpose is to illustrate the topology and decisions made in this cluster. We feel a "step-by-step" flow will help you learn the pieces of the solution and give you insight into the relationship between them. Ultimately, lifecycle/SDLC management of your cluster and its dependencies will depend on your situation (team roles, organizational standards, etc), and will be implemented as appropriate for your organizational and compliance needs.

**Please start this learning journey in the _Preparing for the cluster_ section.** If you follow this through the end, you'll have our recommended baseline cluster for regulated industries installed, with an end-to-end sample workload running for you to reference in your own Azure subscription.

### 1. :rocket: Preparing for the cluster

There are considerations that must be addressed before you start deploying your cluster. Do I have enough permissions in my subscription and AD tenant to do a deployment of this size? How much of this will be handled by my team directly vs having another team be responsible?

* [ ] Begin by ensuring you [install and meet the prerequisites](./01-prerequisites.md).
* [ ] [Plan your Azure Active Directory integration](./03-aad.md).
* [ ] [Apply baseline Azure Policy and Azure Defender configuration](./04-subscription.md) to your target subscription.

### 2. Build regional networking hub

* [ ] [Build the regional hub](./05-networking-hub.md) to control and monitor spoke traffic.

### 3. Build cluster jump box image

* [ ] [Build VM image in isolated network spoke](./06-aks-jumpboximage.md).

### 4. Deploying the cluster

* [ ] [Deploy the target network spoke](./07-cluster-networking.md) that the cluster will be homed to.
* [ ] [Deploy the AKS cluster and supporting services](./08-aks-cluster.md).
* [ ] [Place the cluster under GitOps management](./09-gitops.md).

We perform the prior steps manually here for you to understand the involved components, but we advocate for an automated DevOps process. Therefore, incorporate the prior steps into your CI/CD pipeline, as you would any infrastructure as code (IaC). We have included [a starter GitHub workflow](./github-workflow/aks-deploy.yaml) that demonstrates this.

### 5. Deploy your workload

Without a workload deployed to the cluster it will be hard to see how these decisions come together to work as a reliable application platform for your business. The deployment of this workload would typically follow a CI/CD pattern and may involve even more advanced deployment strategies (blue/green, etc). The following steps represent a manual deployment, suitable for illustration purposes of this infrastructure.

* [ ] Just like the cluster, there are [workload prerequisites to address](./10-workload-prerequisites.md)
* [ ] [Configure AKS Ingress Controller with Azure Key Vault integration](./13-secret-management-and-ingress-controller.md)
* [ ] [Deploy the workload](./12-workload.md)

### 6. :checkered_flag: Validation

Now that the cluster and the sample workload is deployed; now it's time to look at how the cluster is functioning.

* [ ] [Perform end-to-end deployment validation](./13-validation.md)

## :broom: Clean up resources

Most of the Azure resources deployed in the prior steps will incur ongoing charges unless removed.

* [ ] [Cleanup all resources](./14-cleanup.md)

## Inner-loop development scripts

We have provided some sample deployment scripts that you could adapt for your own purposes while doing a POC/spike on this. Those scripts are found in the [inner-loop-scripts directory](./inner-loop-scripts). They include some additional considerations and may include some additional narrative as well. Consider checking them out. They consolidate most of the walk-through performed above into combined execution steps.

## Preview features

While this reference implementation tends to avoid _preview_ features of AKS to ensure you have the best customer support experience; there are some features you may wish to evaluate in pre-production clusters that augment your posture around security, manageability, etc. Consider trying out and providing feedback on the following. As these features come out of preview, this reference implementation may be updated to incorporate them.

* [Azure RBAC for Kubernetes Authentication](https://docs.microsoft.com/azure/aks/manage-azure-rbac) - An extension of the Azure AD integration already in this reference implementation. Allowing you to bind Kubernetes authentication to Azure RBAC role assignments.
* [Host-based encryption](https://docs.microsoft.com/azure/aks/enable-host-encryption) - Leverages added data encryption on your VMs' temp and OS disks.
* [Generation 2 VM support](https://docs.microsoft.com/azure/aks/cluster-configuration#generation-2-virtual-machines-preview) - Increased memory options, Intel SGX support, and UEFI-based boot architectures.
* [Auto Upgrade Profile support](https://github.com/Azure/AKS/issues/1303)
* [Customizable Node & Kublet config](https://github.com/Azure/AKS/issues/323)
* [GitOps as an add-on](https://github.com/Azure/AKS/issues/1967)
* [Azure AD Pod Identity as an add-on](https://docs.microsoft.com/azure/aks/use-azure-ad-pod-identity)

## Advanced topics

This reference implementation intentionally does not cover more advanced scenarios. For example topics like the following are not addressed:

* Cluster lifecycle management with regard to SDLC and GitOps
* Workload SDLC integration (including concepts like [Bridge to Kubernetes](https://docs.microsoft.com/visualstudio/containers/bridge-to-kubernetes?view=vs-2019), advanced deployment techniques, etc)
* Mapping decisions to [CIS benchmark controls](https://www.cisecurity.org/benchmark/kubernetes/)
* Container security
* Multi-region clusters
* [Advanced regulatory compliance](https://github.com/Azure/sg-aks-workshop) (FinServ)
* Multiple (related or unrelated) workloads owned by the same team
* Multiple workloads owned by disparate teams (AKS as a shared platform in your organization)
* Cluster-contained state (PVC, etc)
* Windows node pools
* Scale-to-zero node pools and event-based scaling (KEDA)
* [Terraform](https://docs.microsoft.com/azure/developer/terraform/create-k8s-cluster-with-tf-and-aks)
* [Bedrock](https://github.com/microsoft/bedrock)
* [dapr](https://github.com/dapr/dapr)

Keep watching this space, as we build out reference implementation guidance on topics such as these. Further guidance delivered will use this baseline AKS implementation as their starting point. If you would like to contribute or suggest a pattern built on this baseline, [please get in touch](./CONTRIBUTING.md).

## Final thoughts

Kubernetes is a very flexible platform, giving infrastructure and application operators many choices to achieve their business and technology objectives. At points along your journey, you will need to consider when to take dependencies on Azure platform features, OSS solutions, support channels, regulatory compliance, and operational processes. **We encourage this reference implementation to be the place for you to _start_ architectural conversations within your own team; adapting to your specific requirements, and ultimately delivering a solution that delights your customers.**

## Related documentation

* [Azure Kubernetes Service Documentation](https://docs.microsoft.com/azure/aks/)
* [Microsoft Azure Well-Architected Framework](https://docs.microsoft.com/azure/architecture/framework/)
* [Microservices architecture on AKS](https://docs.microsoft.com/azure/architecture/reference-architectures/containers/aks-microservices/aks-microservices)

## Contributions

Please see our [contributor guide](./CONTRIBUTING.md).

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact <opencode@microsoft.com> with any additional questions or comments.

With :heart: from Microsoft Patterns & Practices, [Azure Architecture Center](https://aka.ms/architecture).
