using 'main.bicep'

param name = 'mAKS'
param location = 'northeurope'
param environment = 'dev'
param adminGroupObjectIDs = ['56d2b35d-23cd-43e9-bef9-7b1e4b2fdf5b']
param snetPrivateEndpointName = 'snetPrivateEndpointName'
//param snetManagmentCrAgentsName = 'snetManagmentCrAgentsName'
param vnetName = 'clickops-vnet'
param vnetRgName = 'clickops-vnet'
param deployAzDiagnostics = false

param kubernetesVersion = '1.26.6'
param nodePools = [
  {
    name: 'npsystem'
    count: 2
    vmSize: 'Standard_B2s'
    osDiskSizeGB: 30
    osDiskType: 'Ephemeral'
    osType: 'Linux'
    osSKU: 'Ubuntu'
    minCount: 2
    maxCount: 5
    vnetSubnetName: 'snetClusterSystemNodePools'
    enableAutoScaling: true
    type: 'VirtualMachineScaleSets'
    mode: 'System'
    scaleSetPriority: 'Regular'
    scaleSetEvictionPolicy: 'Delete'
    enableNodePublicIP: false
    maxPods: 110
    availabilityZones: ['1','2','3']
    upgradeSettings: {
      maxSurge: '33%'
    }
    // This can be used to prevent unexpected workloads from landing on system node pool. All add-ons support this taint.
    // nodeTaints: [
    //   'CriticalAddonsOnly=true:NoSchedule'
    // ]
    nodeLabels: {
      'pci-scope': 'in-scope'
    }
    tags: {
      'pci-scope': 'out-of-scope'
      'Data classification': 'Confidential'
      'Business unit': 'X0001'
      'Business criticality': 'Business unit-critical'
    }
  }
  {
    name: 'npinscope01'
    count: 2
    vmSize: 'Standard_B2s'
    osDiskSizeGB: 30
    osDiskType: 'Ephemeral'
    osType: 'Linux'
    osSKU: 'Ubuntu'
    minCount: 2
    maxCount: 5
    vnetSubnetName: 'snetClusterInScopeNodePools'
    enableAutoScaling: true
    type: 'VirtualMachineScaleSets'
    mode: 'User'
    scaleSetPriority: 'Regular'
    scaleSetEvictionPolicy: 'Delete'
    enableNodePublicIP: false
    maxPods: 110
    availabilityZones: ['1','2','3']
    upgradeSettings: {
      maxSurge: '33%'
    }
    nodeLabels: {
      'pci-scope': 'in-scope'
    }
    tags: {
      'pci-scope': 'in-scope'
      'Data classification': 'Confidential'
      'Business unit': 'X0001'
      'Business criticality': 'Business unit-critical'
    }
  }
  {
    name: 'npooscope01'
    count: 2
    vmSize: 'Standard_B2s'
    osDiskSizeGB: 30
    osDiskType: 'Ephemeral'
    osType: 'Linux'
    minCount: 2
    maxCount: 5
    vnetSubnetName: 'snetClusterOutScopeNodePools'
    enableAutoScaling: true
    type: 'VirtualMachineScaleSets'
    mode: 'User'
    scaleSetPriority: 'Regular'
    scaleSetEvictionPolicy: 'Delete'
    enableNodePublicIP: false
    maxPods: 30
    availabilityZones: ['1','2','3'] //pickZones('Microsoft.Compute', 'virtualMachineScaleSets', location, 3)
    upgradeSettings: {
      maxSurge: '33%'
    }
    nodeLabels: {
      'pci-scope': 'out-of-scope'
    }
    tags: {
      'pci-scope': 'out-of-scope'
      'Data classification': 'Confidential'
      'Business unit': 'X0001'
      'Business criticality': 'Business unit-critical'
    }
  }
]
param networkProfile = {
  networkPlugin: 'azure'
  loadBalancerSku: 'standard'
  dnsServiceIP: '172.16.0.10'
  serviceCidr: '172.16.0.0/16'
  podCidr:  '172.18.0.0/16'
  networkPolicy: 'calico'
  networkPluginMode: 'overlay'
}
param privateDNSZoneId = 'none' //privateDNSZoneName l8s if needed
param workspaceId = ''
