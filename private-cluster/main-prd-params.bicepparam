using 'main.bicep'

param name = 'prd'
param location = 'northeurope'
param environment = 'prd'
param admingroupobjectid = ''
param systemNodePoolSubnetName string
param availabilityZoneCount int

var nodePools = [
  {
    name: 'npsystem'
    count: 2
    vmSize: 'Standard_DS2_v2'
    osDiskSizeGB: 80
    osDiskType: 'Ephemeral'
    osType: 'Linux'
    osSKU: 'Ubuntu'
    minCount: 2
    maxCount: 5
    vnetSubnetID: resourceId(vnetRgName, 'Microsoft.Network/virtualNetworks/subnets', vnetSpoke, 'snetClusterSystemNodePools')
    enableAutoScaling: true
    type: 'VirtualMachineScaleSets'
    mode: 'System'
    scaleSetPriority: 'Regular'
    scaleSetEvictionPolicy: 'Delete'
    orchestratorVersion: kubernetesVersion
    enableNodePublicIP: false
    maxPods: 110
    availabilityZones: pickZones('Microsoft.Compute', 'virtualMachineScaleSets', location, availabilityZoneCount)
    upgradeSettings: {
      maxSurge: '33%'
    }
    // This can be used to prevent unexpected workloads from landing on system node pool. All add-ons support this taint.
    // nodeTaints: [
    //   'CriticalAddonsOnly=true:NoSchedule'
    // ]
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
    vmSize: 'Standard_DS2_v2'
    osDiskSizeGB: 120
    osDiskType: 'Ephemeral'
    osType: 'Linux'
    osSKU: 'Ubuntu'
    minCount: 2
    maxCount: 5
    vnetSubnetID: resourceId(vnetRgName, 'Microsoft.Network/virtualNetworks/subnets', vnetSpoke, 'snetClusterInScopeNodePools')
    enableAutoScaling: true
    type: 'VirtualMachineScaleSets'
    mode: 'User'
    scaleSetPriority: 'Regular'
    scaleSetEvictionPolicy: 'Delete'
    orchestratorVersion: kubernetesVersion
    enableNodePublicIP: false
    maxPods: 110
    availabilityZones: pickZones('Microsoft.Compute', 'virtualMachineScaleSets', location, availabilityZoneCount)
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
    vmSize: 'Standard_DS2_v2'
    osDiskSizeGB: 120
    osDiskType: 'Ephemeral'
    osType: 'Linux'
    minCount: 2
    maxCount: 5
    vnetSubnetID: resourceId(vnetRgName, 'Microsoft.Network/virtualNetworks/subnets', vnetSpoke, 'snetClusterOutScopeNodePools')
    enableAutoScaling: true
    type: 'VirtualMachineScaleSets'
    mode: 'User'
    scaleSetPriority: 'Regular'
    scaleSetEvictionPolicy: 'Delete'
    orchestratorVersion: kubernetesVersion
    enableNodePublicIP: false
    maxPods: 30
    availabilityZones: availabilityZones //pickZones('Microsoft.Compute', 'virtualMachineScaleSets', location, 3)
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

param kubernetesVersion = '1.26.6'
param nodePools = nodePools
param podCidr = ''
param dnsServiceIP = ''
param serviceCidr = ''
param workspaceName = '' //log-mgmt-swc-201
param workspaceGroupName = '' //rg-log-mgmt-002
param workspaceSubscriptionId = '' //shb-platform-management-201
