# Deploy the regulated industries AKS cluster

Now that the all the [necessary bootstrapping requirements are deployed](./09-pre-cluster-stamp.md), the next step in the [AKS baseline for regulated workloads reference implementation](/) is deploying the AKS cluster, built on its [security-hardened OS](https://learn.microsoft.com/azure/aks/security-hardened-vm-host-image) and its adjacent Azure resources.

## Expected results

- The cluster and all adjacent resources are deployed.
  - This includes core infrastructure such as Azure Application Gateway.
  - Private Link configuration
  - Jump box (Azure Bastion) access

## Steps

1. Get the already-deployed, Virtual Network resource ID that this cluster will be attached to.

   ```bash
   RESOURCEID_VNET_CLUSTERSPOKE=$(az deployment group show -g rg-enterprise-networking-spokes -n spoke-BU0001A0005-01 --query properties.outputs.clusterVnetResourceId.value -o tsv)
   echo RESOURCEID_VNET_CLUSTERSPOKE: $RESOURCEID_VNET_CLUSTERSPOKE
   ```

1. Identify your jump box image.

   ```bash
   # If you used a pre-existing image and not the one built by this walk through, replace the command below with the resource id of that image.
   RESOURCEID_IMAGE_JUMPBOX=$(az deployment group show -g rg-bu0001a0005 -n CreateJumpBoxImageTemplate --query 'properties.outputs.distributedImageResourceId.value' -o tsv)
   echo RESOURCEID_IMAGE_JUMPBOX: $RESOURCEID_IMAGE_JUMPBOX
   ```

1. Convert your jump box cloud-init (users) file to Base64.

   ```bash
   CLOUDINIT_BASE64=$(base64 jumpBoxCloudInit.yml | tr -d '\n')
   ```

   If you need to perform this in Powershell, you can achieve the same with this.

   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes('jumpBoxCloudInit.yml'))
   ```

1. Deploy the cluster ARM template.

   > *Alteratively 🛑*, you could set these values in [`azuredeploy.parameters.prod.json`](../../azuredeploy.parameters.prod.json) file instead of the individual key-value pairs shown below. You'll be redeploying a slight evolution of this template a later time in this walkthrough, and you might find it easier to have these variables captured in the parameters file as they will not change for the second deployment.

   ```bash
   GITOPS_REPOURL=$(git config --get remote.origin.url)
   echo GITOPS_REPOURL: $GITOPS_REPOURL

   GITOPS_CURRENT_BRANCH_NAME=$(git branch --show-current)
   echo GITOPS_CURRENT_BRANCH_NAME: $GITOPS_CURRENT_BRANCH_NAME

   # [This takes about 20 minutes to run.]
   az deployment group create -g rg-bu0001a0005 -f cluster-stamp.bicep -p targetVnetResourceId=${RESOURCEID_VNET_CLUSTERSPOKE} clusterAdminEntraGroupObjectId=${OBJECTID_GROUP_CLUSTERADMIN} k8sControlPlaneAuthorizationTenantId=${TENANTID_K8SRBAC} appGatewayListenerCertificate=${APP_GATEWAY_LISTENER_CERTIFICATE_BASE64} jumpBoxImageResourceId=${RESOURCEID_IMAGE_JUMPBOX} jumpBoxCloudInitAsBase64=${CLOUDINIT_BASE64} gitOpsBootstrappingRepoHttpsUrl=${GITOPS_REPOURL} gitOpsBootstrappingRepoBranch=${GITOPS_CURRENT_BRANCH_NAME}

   # Or if you updated and wish to use the parameters file …
   #az deployment group create -g rg-bu0001a0005 -f cluster-stamp.bicep -p "@azuredeploy.parameters.prod.json"
   ```

### Next step

:arrow_forward: [Validate cluster access and bootstrapping.md](./11-validate-cluster-access-and-bootstrapping.md)
