using 'main.bicep'

var aksNodePools = {
  agentPoolProfiles: [
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
        vnetSubnetID:  //vnetSpoke::snetClusterSystemNodePools.id
        enableAutoScaling: true
        type: 'VirtualMachineScaleSets'
        mode: 'System'
        scaleSetPriority: 'Regular'
        scaleSetEvictionPolicy: 'Delete'
        orchestratorVersion: kubernetesVersion
        enableNodePublicIP: false
        maxPods: 110
        availabilityZones: pickZones('Microsoft.Compute', 'virtualMachineScaleSets', location, 3)
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
          'Business unit': 'BU0001'
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
        vnetSubnetID: vnetSpoke::snetClusterInScopeNodePools.id
        enableAutoScaling: true
        type: 'VirtualMachineScaleSets'
        mode: 'User'
        scaleSetPriority: 'Regular'
        scaleSetEvictionPolicy: 'Delete'
        orchestratorVersion: kubernetesVersion
        enableNodePublicIP: false
        maxPods: 110
        availabilityZones: pickZones('Microsoft.Compute', 'virtualMachineScaleSets', location, 3)
        upgradeSettings: {
          maxSurge: '33%'
        }
        nodeLabels: {
          'pci-scope': 'in-scope'
        }
        tags: {
          'pci-scope': 'in-scope'
          'Data classification': 'Confidential'
          'Business unit': 'BU0001'
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
        vnetSubnetID: vnetSpoke::snetClusterOutScopeNodePools.id
        enableAutoScaling: true
        type: 'VirtualMachineScaleSets'
        mode: 'User'
        scaleSetPriority: 'Regular'
        scaleSetEvictionPolicy: 'Delete'
        orchestratorVersion: kubernetesVersion
        enableNodePublicIP: false
        maxPods: 30
        availabilityZones: pickZones('Microsoft.Compute', 'virtualMachineScaleSets', location, 3)
        upgradeSettings: {
          maxSurge: '33%'
        }
        nodeLabels: {
          'pci-scope': 'out-of-scope'
        }
        tags: {
          'pci-scope': 'out-of-scope'
          'Data classification': 'Confidential'
          'Business unit': 'BU0001'
          'Business criticality': 'Business unit-critical'
        }
      }
    ]  
}

param resourceName
param location
param kubernetesVersion
param aksNodepools = aksNodePools
param vnetName
param vnetRgName
