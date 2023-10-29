# Networking Azure Resource Manager (ARM) Templates

This is part of the Azure Kubernetes Service (AKS) Baseline Cluster for Regulated Workloads.. For more information see the [readme file in the root](/README.md). These files are the ARM templates used in the deployment of this reference implementation. This reference implementation uses a standard hub-spoke model.

## Files

* [`hub-region.v0.bicep`](./hub-region.v0.bicep) is a file that defines a generic regional hub. All regional hubs can generally be considered a fork of this base template.
* [`hub-region.v1.bicep`](./hub-region.v1.bicep) is an updated version that defines a specific region's hub (for example, it might be named `hub-eastus2.bicep`). This is the long-lived template that defines this specific region's hub. This version has support for our image builder process.
* [`hub-region.v2.bicep`](./hub-region.v2.bicep) is an even more updated version that defines a specific region's hub (it would still be the same named `hub-eastus2.bicep` file). This version has support for our image builder process plus our AKS cluster's needs.
* [`spoke-BU0001A0005-00.bicep`](./spoke-BU0001A0005-00.bicep) is a file that defines a specific spoke in the topology. A spoke is created for each workload in a business unit, hence the naming pattern in the file name. This spoke contains the networking resources for the image builder process.
* [`spoke-BU0001A0005-01.bicep`](./spoke-BU0001A0005-01.bicep) is a file that defines a specific spoke in the topology. This spoke contains the networking resources for the AKS cluster.

Your organization will likely have its own standards for their hub-spoke or vwan implementation. Be sure to follow your organizational guidelines.

## See also

* [Hub-spoke network topology in Azure](https://learn.microsoft.com/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)
