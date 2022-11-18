# Prep for cluster bootstrapping

Now that the [hub-spoke network is provisioned](./04-networking.md), the next step in the [AKS baseline reference implementation](./) is preparing what your AKS cluster should be bootstrapped with.

## Expected results

Container registries often have a lifecycle that extends beyond the scope of a single cluster. They can be scoped broadly at organizational or business unit levels, or can be scoped at workload levels, but usually are not directly tied to the lifecycle of any specific cluster instance. For example, you may do blue/green _cluster instance_ deployments, both using the same container registry. Even though clusters came and went, the registry stays intact.

- Azure Container Registry (ACR) is deployed, and exposed as a private endpoint.
- ACR is populated with images your cluster will need as part of its bootstrapping process.
- Log Analytics is deployed and ACR platform logging is configured. This workspace will be used by your cluster as well.

The role of this pre-existing ACR instance is made more prominant when we think about cluster bootstrapping. That is the process that happens after Azure resource deployment of the cluster, but before your first workload lands in the cluster. The cluster will be bootstrapped _immedately and automatically_ after resource deployment, which means you'll need ACR in place to act as your official OCI artifact repository for required images and Helm charts used in that bootstrapping process.

## Steps

1. Get the AKS cluster spoke virtual network resource ID.

   > :book: The app team will be deploying to a spoke virtual network, that was already provisioned by the network team.

   ```bash
   export RESOURCEID_VNET_CLUSTERSPOKE=$(az deployment group show -g rg-enterprise-networking-spokes -n spoke-BU0001A0005-01 --query properties.outputs.clusterVnetResourceId.value -o tsv)
   echo RESOURCEID_VNET_CLUSTERSPOKE: $RESOURCEID_VNET_CLUSTERSPOKE
   ```
1. Deploy the container registry template.

   ```bash
   # [This takes about eight minutes.]
   az deployment group create -g rg-bu0001a0005 -f acr-stamp.bicep -p geoRedundancyLocation=northcentralus targetVnetResourceId=${RESOURCEID_VNET_CLUSTERSPOKE} location=eastus2
   ```

### Next step

:arrow_forward: [Populate ACR](./10-pre-bootstrap.md)

