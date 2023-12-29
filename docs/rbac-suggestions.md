# Workload/platform separation via RBAC

This reference implementation is mostly focused on infrastructure, and minimal attention to the concerns of the workload itself. Which, we acknowledge is incomplete from a regulatory compliance perspective. We hope to extend this reference implementation or build a companion on top of this one that will focus mainly on the workload side of things. However, here is some recommendations, even if they are not implemented directly here in this reference implementation.

## Role ideas

If you're looking for a list of recommended roles to delineate responsibilities across, consider the following. Obviously you'll need to build roles that are reasonable for your organization and workload.

> :notebook: For more information, see [Azure Architecture Center guidance for PCI-DSS 3.2.1 Requirement 7.1.1 in AKS](https://learn.microsoft.com/azure/architecture/reference-architectures/containers/aks-pci/aks-pci-identity#requirement-711).

- **Application Developers** are responsible for developing software in service to the business. All code developed by this role is subject to a set of training and quality gates upholding compliance, attestation, and release management processes. This role might be granted some read privileges in related Kubernetes namespaces and read privileges on related workload Azure resources, but this role is not responsible for deploying or modifying any transitioning state in a running system. This team may manage build pipelines, but usually not deployment pipelines.

- **Application Owners** are responsible for defining and prioritizing features; aligning with business outcomes. They need to understand how features impact the compliance scoping of the workload, and balance customer data protection and ownership with business objectives.

- **Application Operators/SRE** have skills similar to Application Developers but their mission is intended to use a relatively deep understanding of the code base, to develop a deep expertise on troubleshooting, observability standards, operations (scaling and dependency management) and live-site processes. Application Devs and SRE work very closely together to improve availability, scalability and performance of the applications. This role is usually highly privileged within the scope of the application (Related Kubernetes Namespaces) and it's related Azure resources (such as databases and key vaults). This role often will manage the "last-mile" deployment pipeline, and may help the Application Developers manage the build pipelines. While this role will likely having standing access to parts of the Kubernetes cluster, minimize privileged access to JIT.

- **Infrastructure Owners** are responsible for the architecture, connectivity and functionality of services deployed and maintained in the company IT department (this encompasses Public Cloud hosted services, and on-premises/private Azure cloud services). They are concerned with ensuring the infrastructure is cost effective and provides the appropriate capabilities such as connectivity, data retention, business continuity features, and so on. This role usually does not get involved in the operations of any given cluster, and likely would have no privilege within a cluster, but may require access to platform logs and Cost Center data.

- **Infrastructure Operators/SRE** are concerned with the health of the container hosting infrastructure and dependent services. They ensure the platform offers appropriate capacity and availability to Application Developers and Application Operators. Specifically this can be thought of as "the cluster owner" role. They run the platform in which the workload will be deployed to. This team will manage the build, deploy, and bootstrap pipeline for the cluster, working with the Infrastructure Owners to ensure a suitable landing zone exists for the cluster. This role may need to oversee workload Namespaces in a readonly sense (for concerns like Quota, Limits, OOM alerts), but this role doesn't manage the workload. This role will likely bootstrap workload namespaces with requires zero-trust policies and set quotas. Application Operators should work with the Infrastructure Operators to ensure an understanding of target node pools, expected sizing and scale requirements, and so on.

- **Policy/Security Owners** are have deep security or regulation compliance expertise. Their accountability rests in the definition and encoding of company policies that protect the security and regulatory compliance of the company employees, its assets, and those of the company's customers. It is the company's goal to encode and automate as many of these policies as possible, and to enforce very high standards around their versioning, attestation, and release management. This role will work closely with all of the above roles to ensure policy is applied and auditable through every phase.

You may also have additional specialty roles in the mix such as **Database Administrators (DBA)**, **Data Scientists (AI/ML)**, **Business Intelligence (Power BI)**, and so on. These lists are not exhaustive, but instead to be used as a starting point for your compliance requirements of documenting the separation of roles and responsibilities. Specifically decentralized vs centralized IT functions may affect this list; such as a typical DevSecOps workload team that owns their own Azure infrastructure end-to-end with minimal to no centralized IT involvement. While the specifics of your situation is unique, the general responsibilities are not.

There will be latitude on where these roles will overlap. For example maybe the Application Operators and Infrastructure Operators decide to co-mingle container images on the same Azure Container Registry instance and treat that as a shared platform due to cost concerns. Or maybe Infrastructure Operators provide an even more centralized Container Registry that is mandated to be used by all because a dedicated SRE team has formed around it. The "who owns what, and why" question will come up as you design your roles and responsibilities. Decide what works for you and document that decision. You can always adjust that decision later Maybe what worked for one or two regulated workloads no longer works when there are 15 in your portfolio. Maybe you designing for 15 in-scope workloads from the start, but found the business growth wasn't there and you're left with just one or two. Inspect, adapt, and document the new reality.

Consider the scope of roles and responsibilities over topics such as:

- Source Code repository (GitHub Enterprise, Azure DevOps, GitLab, and so on)
- Key Vaults
- Resource Groups / Subscriptions
- Azure Management Groups
- Azure Policy (workload-centric), Azure Policy (subscription-centric)
- Container Registries
- Databases
- Pipelines (Build and Deploy)
- Azure Resources (ARM templates)
- Training and Certification
- TLS certificate authority
- Live-site access patterns
- Preproduction environments

### Microsoft Entra objects

Formalize your Microsoft Entra structure around roles and responsibilities as well. For example, consider items like the following.

- Infrastructure Operators
  - A single **Service Principal** solely responsible for Azure Resource deployment for Azure resources. This would be the cluster and other Azure resources on the same lifecycle. (such as `bu001a005-infra-pipeline`)
  - A single **Group** that is used at the break-glass group that allows full control over the Kubernetes cluster. No standing group membership. (such as `bu001a005-infra-admins`)
  - A single **Group** that is used for standing permissions within a cluster. These are permissions that are required for day-to-day operations by the Infrastructure Operator, but should not be highly privileged. (such as `bu001a005-infra-admins-daily`)
- Application Developers
  - A single **Group** that contains all the Application Developers for an application. They may have standing read permissions within defined scopes within Azure (such as Application Insights) and the workload namespaces. These scopes and permissions may be different between preproduction and production environments. (such as `bu001a005-app-devs-daily`)
- Application Operators
  - A single **Service Principal** solely responsible for Azure Resource deployment. This would be for workload-centric resource deployments. (such as `bu001a005-app-ops-infra-pipeline`)
  - A single **Service Principal** solely responsible for Kubernetes deployments. This would be for automated deployments into the cluster. This might not be needed if workloads are also deployed via GitOps in a "pull-into-the-cluster" model vs a "push-into-the-cluster" model. (such as `bu001a005-app-ops-[clusterName]-pipeline`)
  - A single **Group** that is allows full control within their allocated namespaces. Ideally no standing group membership. (such as `bu001a005-app-ops-admins`)
  - A single **Group** that is used for standing permissions within their allocated namespaces. These are permission that are required for day-to-day operations by the Application Operator, but should not be highly privileged. (such as `bu001a005-app-ops-daily`)
- Application Owners
  - A single **Group** that contains all the Application Owners for an application. They likely will have group-based access to reports generated by BI or select Azure concerns like Cost Center or Azure Dashboards, but unlikely to have any in-cluster or cluster-level permissions assigned. (such as `bu001a005-app-owners`)

If you have multiple clusters as part of your portfolio, create separate groups per cluster when the group is applied as Kubernetes RBAC, especially for the highly privileged groups. Ensure that service principals used for any resource deployment (Azure or Kubernetes) are not shared across preproduction and production environments.

### Microsoft Entra ID mapping to cluster

The above, where they materialize in-cluster, would be mapped to distinct, custom Kubernetes `ClusterRole` definitions (such as `name: infraAdmin`) and then a singular `ClusterRoleBinding` to the related group above. And for those that are namespaced, to `Role` definitions (such as `name: appAdmin`) and then a singular `RoleBinding` to the related group above -- for each related namespace. "Shared Services" in a cluster will live in their own namespace (such as a security agent), and while a `ClusterRoleBinding` might work for management of those, consider instead managing those as an independent workload, and managing those through `Role` and `RoleBinding` constructs, that you apply to Infrastructure Operators.

## Next step

:arrow_forward: [Back to main README](/README.md#separation-of-duties)
