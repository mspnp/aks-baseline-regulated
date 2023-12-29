# Workload

This is part of the Azure Kubernetes Service (AKS) Baseline Cluster for Regulated Workloads. For more information see the [readme file in the root](/README.md).

This reference implementation is focused on the infrastructure of a secure, AKS cluster used for a workload in scope for compliance. The workload is not fully addressed as part of that scope, moreso the cluster infrastructure. However, to demonstrate the concepts and configuration presented in this cluster, a workload needed to be defined.

The workload is spread across two namespaces, `a0005-i` and `a0005-o` representing components that are directly in-scope (`-i`) and components that themselves are not in-scope, but need to be adjacent (`-o`) to the in-scope workload.

The workload will take advantage of the shared ingress controller and Open Service Mesh installation that the [Infrastructure Operator](/docs/rbac-suggestions#role-ideas) installed on the cluster.

## a0005-i

This is the "in scope" namespace. It's pods ideally will be targeting the matching, dedicated "in scope" nodepool. There is a zero-trust network policy applied to this namespace and this namespace is enrolled in the workload service mesh.

### web-frontend

This is an ASP.NET 5.0 application that kicks off a series of network calls in the cluster to report on allowed traffic flows. This is what your ingress controller will be routing traffic to. It can communicate to microservice-a only (in the a0005-o namespace).

### microservice-c

This is an ASP.NET 5.0 application that attempts to make network contact with other elements in the cluster, and the Internet. Based on Kubernetes Network Policies and service mesh policies, this service cannot communicate to anything.

## a0005-o

This is the "out of scope" namespace. It's pods ideally will be targeting the matching, dedicated "out of scope" nodepool. There is a zero-trust network policy applied to this namespace and this namespace is enrolled in the workload service mesh.

### microservice-a

This is an ASP.NET 5.0 application that attempts to make network contact with other elements in the cluster, and the Internet. Based on Kubernetes Network Policies and service mesh policies, this service can only communicate to microservice-b (in the same namespace).

### microservice-b

This is an ASP.NET 5.0 application that attempts to make network contact with other elements in the cluster, and the Internet. Based on Kubernetes Network Policies and service mesh policies, this service can only communicate to microservice-c (in the a0005-i namespace).

## mTLS

All communication within the mesh is mTLS encrypted due to the features of the service mesh. Likewise, the communication between the Ingress Controller and the web-frontend, is also TLS encrypted.
