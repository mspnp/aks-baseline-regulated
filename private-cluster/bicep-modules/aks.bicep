// Reqs 
// EncryptionAtHost 
// az feature register --namespace microsoft.compute --name EncryptionAtHost
// az provider register -n microsoft.compute

// params
param location string
param name string
//param nodeResourceGroup string
param podCidr string
param dnsServiceIP string
param serviceCidr string
param adminGroupObjectIDs string
param networkPlugin string
param kubernetesVersion string
param nodePools array

// vars
var managedIdentityOperatorDefId = 'f1a07417-d97a-45cb-824c-7a7467783830' // Managed Identity Operator

// Existing resources
resource umi 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: 'umi-${name}'
}

resource la 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' existing = {
  name: 'la-${name}'
}

// AKS
resource aks 'Microsoft.ContainerService/managedClusters@2023-07-02-preview' = {
  name: 'aks-${name}'
  location: location
  tags: {
    'Data classification': 'Confidential'
    'Business unit': 'BU0001'
    'Business criticality': 'Business unit-critical'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${umi.id}': {}
    }
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: uniqueString(subscription().subscriptionId, resourceGroup().id, clusterName)
    agentPoolProfiles: nodePools /*[
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
    ]*/
    servicePrincipalProfile: {
      clientId: 'msi'
    }
    addonProfiles: {
      httpApplicationRouting: {
        enabled: false
      }
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceId: la.id
          useAADAuth: 'true'
        }
      }
      aciConnectorLinux: {
        enabled: false
      }
      azurepolicy: {
        enabled: true
        config: {
          version: 'v2'
        }
      }
      openServiceMesh: {
        enabled: true
        config: {
        }
      }
      azureKeyvaultSecretsProvider: {
        enabled: true
        config: {
          enableSecretRotation: 'false'
        }
      }
    }
    nodeResourceGroup: 'rg-aks-${name}-nodepools'
    enableRBAC: true
    enablePodSecurityPolicy: false
    maxAgentPools: 3
    networkProfile: {
      networkPlugin: networkPlugin
      loadBalancerSku: 'standard'
      dnsServiceIP: dnsServiceIP
      serviceCidr: serviceCidr
      podCidr:  podCidr
      networkPolicy: 'calico'
      networkPluginMode: 'overlay'
      // networkPlugin: 'azure'
      // networkPolicy: 'azure'
      // outboundType: 'userDefinedRouting'
      // loadBalancerSku: 'standard'
      // loadBalancerProfile: json('null')
      // serviceCidr: '172.16.0.0/16'
      // dnsServiceIP: '172.16.0.10'
      // dockerBridgeCidr: '172.18.0.1/16'
    }
    aadProfile: {
      managed: true
      enableAzureRBAC: false
      adminGroupObjectIDs: [
        adminGroupObjectIDs
      ]
      tenantID: tenant().tenantId
    }
    autoScalerProfile: {
      'balance-similar-node-groups': 'false'
      expander: 'random'
      'max-empty-bulk-delete': '10'
      'max-graceful-termination-sec': '600'
      'max-node-provision-time': '15m'
      'max-total-unready-percentage': '45'
      'new-pod-scale-up-delay': '0s'
      'ok-total-unready-count': '3'
      'scale-down-delay-after-add': '10m'
      'scale-down-delay-after-delete': '20s'
      'scale-down-delay-after-failure': '3m'
      'scale-down-unneeded-time': '10m'
      'scale-down-unready-time': '20m'
      'scale-down-utilization-threshold': '0.5'
      'scan-interval': '10s'
      'skip-nodes-with-local-storage': 'true'
      'skip-nodes-with-system-pods': 'true'
    }
    apiServerAccessProfile: {
      enablePrivateCluster: true
      privateDNSZone: pdzMc.id
      enablePrivateClusterPublicFQDN: false
    }
    oidcIssuerProfile: {
      enabled: true
    }
    podIdentityProfile: {
      enabled: false
    }
    autoUpgradeProfile: {
      upgradeChannel: 'stable'
    }
    disableLocalAccounts: true
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
      defender: {
        logAnalyticsWorkspaceResourceId: la.id
        securityMonitoring: {
          enabled: true
        }
      }
    }
  }
  sku: {
    name: 'Base'
    tier: 'Paid' //optional for dev. free tier is not available for production 
  }
  dependsOn: [
    miOperatorRbac
  ]

}

resource miOperatorRbac 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: resourceGroup()
  name: guid(umi.id, managedIdentityOperatorDefId, name)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', managedIdentityOperatorDefId)
    principalId: umi.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Diagnostics

resource aks_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: aks
  name: 'default'
  properties: {
    workspaceId: la.id
    logs: [
      {
        category: 'cluster-autoscaler'
        enabled: true
      }
      {
        category: 'kube-controller-manager'
        enabled: true
      }
      {
        category: 'kube-audit-admin'
        enabled: true
      }
      {
        category: 'guard'
        enabled: true
      }
    ]
  }
}

// Insights

resource sqrPodFailed 'Microsoft.Insights/scheduledQueryRules@2021-08-01' = {
  name: 'PodFailedScheduledQuery'
  location: location
  properties: {
    description: 'Example from: https://learn.microsoft.com/azure/azure-monitor/insights/container-insights-alerts'
    actions: {
      actionGroups: []
    }
    criteria: {
      allOf: [
        {
          metricMeasureColumn: 'FailedCount'
          operator: 'GreaterThan'
          query: 'let trendBinSize = 1m;\r\nKubePodInventory\r\n| distinct ClusterName, TimeGenerated\r\n| summarize ClusterSnapshotCount = count() by bin(TimeGenerated, trendBinSize), ClusterName\r\n| join hint.strategy=broadcast (\r\n    KubePodInventory\r\n    | distinct ClusterName, Computer, PodUid, TimeGenerated, PodStatus\r\n    | summarize TotalCount = count(),\r\n        PendingCount = sumif(1, PodStatus =~ "Pending"),\r\n        RunningCount = sumif(1, PodStatus =~ "Running"),\r\n        SucceededCount = sumif(1, PodStatus =~ "Succeeded"),\r\n        FailedCount = sumif(1, PodStatus =~ "Failed")\r\n        by ClusterName, bin(TimeGenerated, trendBinSize)\r\n    )\r\n    on ClusterName, TimeGenerated \r\n| extend UnknownCount = TotalCount - PendingCount - RunningCount - SucceededCount - FailedCount\r\n| project TimeGenerated,\r\n    ClusterName,\r\n    TotalCount = todouble(TotalCount) / ClusterSnapshotCount,\r\n    PendingCount = todouble(PendingCount) / ClusterSnapshotCount,\r\n    RunningCount = todouble(RunningCount) / ClusterSnapshotCount,\r\n    SucceededCount = todouble(SucceededCount) / ClusterSnapshotCount,\r\n    FailedCount = todouble(FailedCount) / ClusterSnapshotCount,\r\n    UnknownCount = todouble(UnknownCount) / ClusterSnapshotCount\r\n'
          threshold: 3
          timeAggregation: 'Average'
          dimensions: []
          failingPeriods: {
            minFailingPeriodsToAlert: 1
            numberOfEvaluationPeriods: 1
          }
          resourceIdColumn: ''
        }
      ]
    }
    enabled: true
    evaluationFrequency: 'PT5M'
    scopes: [
      aks.id
    ]
    severity: 3
    windowSize: 'PT5M'
    muteActionsDuration: null
    overrideQueryTimeRange: 'P2D'
  }
}

resource maNodeCpuUtilizationHighCI1 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Node CPU utilization high for ${aks.name} CI-1'
  location: 'global'
  properties: {
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'host'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
          metricName: 'cpuUsagePercentage'
          metricNamespace: 'Insights.Container/nodes'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'Node CPU utilization across the cluster.'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      mc.id
    ]
    severity: 3
    targetResourceType: 'microsoft.containerservice/managedclusters'
    windowSize: 'PT5M'
  }
  dependsOn: [
    omsContainerInsights
  ]
}

resource maNodeCpuUtilizationHighCI2 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Node working set memory utilization high for ${aks.name} CI-2'
  location: 'global'
  properties: {
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'host'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
          metricName: 'memoryWorkingSetPercentage'
          metricNamespace: 'Insights.Container/nodes'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'Node working set memory utilization across the cluster.'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      mc.id
    ]
    severity: 3
    targetResourceType: 'microsoft.containerservice/managedclusters'
    windowSize: 'PT5M'
  }
  dependsOn: [
    omsContainerInsights
  ]
}

resource maJobsCompletedMoreThan6hAgoCI11 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Jobs completed more than 6 hours ago for ${aks.name} CI-11'
  location: 'global'
  properties: {
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'controllerName'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'kubernetes namespace'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
          metricName: 'completedJobsCount'
          metricNamespace: 'Insights.Container/pods'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: 0
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'This alert monitors completed jobs (more than 6 hours ago).'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      mc.id
    ]
    severity: 3
    targetResourceType: 'microsoft.containerservice/managedclusters'
    windowSize: 'PT1M'
  }
  dependsOn: [
    omsContainerInsights
  ]
}

resource maContainerCpuUtilizationHighCI9 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Container CPU usage high for ${aks.name} CI-9'
  location: 'global'
  properties: {
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'controllerName'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'kubernetes namespace'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
          metricName: 'cpuExceededPercentage'
          metricNamespace: 'Insights.Container/containers'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: 90
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'This alert monitors container CPU utilization.'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      mc.id
    ]
    severity: 3
    targetResourceType: 'microsoft.containerservice/managedclusters'
    windowSize: 'PT5M'
  }
  dependsOn: [
    omsContainerInsights
  ]
}

resource maContainerWorkingSetMemoryUsageHighCI10 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Container working set memory usage high for ${aks.name} CI-10'
  location: 'global'
  properties: {
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'controllerName'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'kubernetes namespace'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
          metricName: 'memoryWorkingSetExceededPercentage'
          metricNamespace: 'Insights.Container/containers'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: 90
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'This alert monitors container working set memory utilization.'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      mc.id
    ]
    severity: 3
    targetResourceType: 'microsoft.containerservice/managedclusters'
    windowSize: 'PT5M'
  }
  dependsOn: [
    omsContainerInsights
  ]
}

resource maPodsInFailedStateCI4 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Pods in failed state for ${aks.name} CI-4'
  location: 'global'
  properties: {
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'phase'
              operator: 'Include'
              values: [
                'Failed'
              ]
            }
          ]
          metricName: 'podCount'
          metricNamespace: 'Insights.Container/pods'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: 0
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'Pod status monitoring.'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      mc.id
    ]
    severity: 3
    targetResourceType: 'microsoft.containerservice/managedclusters'
    windowSize: 'PT5M'
  }
  dependsOn: [
    omsContainerInsights
  ]
}

resource maDiskUsageHighCI5 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Disk usage high for ${aks.name} CI-5'
  location: 'global'
  properties: {
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'host'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'device'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
          metricName: 'DiskUsedPercentage'
          metricNamespace: 'Insights.Container/nodes'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'This alert monitors disk usage for all nodes and storage devices.'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      mc.id
    ]
    severity: 3
    targetResourceType: 'microsoft.containerservice/managedclusters'
    windowSize: 'PT5M'
  }
  dependsOn: [
    omsContainerInsights
  ]
}

resource maNodesInNotReadyStatusCI3 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Nodes in not ready status for ${aks.name} CI-3'
  location: 'global'
  properties: {
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'status'
              operator: 'Include'
              values: [
                'NotReady'
              ]
            }
          ]
          metricName: 'nodesCount'
          metricNamespace: 'Insights.Container/nodes'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: 0
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'Node status monitoring.'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      mc.id
    ]
    severity: 3
    targetResourceType: 'microsoft.containerservice/managedclusters'
    windowSize: 'PT5M'
  }
  dependsOn: [
    omsContainerInsights
  ]
}

resource maContainersGettingOomKilledCI6 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Containers getting OOM killed for ${aks.name} CI-6'
  location: 'global'
  properties: {
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'kubernetes namespace'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'controllerName'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
          metricName: 'oomKilledContainerCount'
          metricNamespace: 'Insights.Container/pods'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: 0
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'This alert monitors number of containers killed due to out of memory (OOM) error.'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      mc.id
    ]
    severity: 3
    targetResourceType: 'microsoft.containerservice/managedclusters'
    windowSize: 'PT1M'
  }
  dependsOn: [
    omsContainerInsights
  ]
}

resource maPersistentVolumeUsageHighCI18 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Persistent volume usage high for ${aks.name} CI-18'
  location: 'global'
  properties: {
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'podName'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'kubernetesNamespace'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
          metricName: 'pvUsageExceededPercentage'
          metricNamespace: 'Insights.Container/persistentvolumes'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'This alert monitors persistent volume utilization.'
    enabled: false
    evaluationFrequency: 'PT1M'
    scopes: [
      mc.id
    ]
    severity: 3
    targetResourceType: 'microsoft.containerservice/managedclusters'
    windowSize: 'PT5M'
  }
  dependsOn: [
    omsContainerInsights
  ]
}

resource maPodsNotInReadyStateCI8 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Pods not in ready state for ${aks.name} CI-8'
  location: 'global'
  properties: {
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'controllerName'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'kubernetes namespace'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
          metricName: 'PodReadyPercentage'
          metricNamespace: 'Insights.Container/pods'
          name: 'Metric1'
          operator: 'LessThan'
          threshold: 80
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'This alert monitors for excessive pods not in the ready state.'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      mc.id
    ]
    severity: 3
    targetResourceType: 'microsoft.containerservice/managedclusters'
    windowSize: 'PT5M'
  }
  dependsOn: [
    omsContainerInsights
  ]
}

resource maRestartingContainerCountCI7 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Restarting container count for ${aks.name} CI-7'
  location: 'global'
  properties: {
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'kubernetes namespace'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'controllerName'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
          metricName: 'restartingContainerCount'
          metricNamespace: 'Insights.Container/pods'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: 0
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'This alert monitors number of containers restarting across the cluster.'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      mc.id
    ]
    severity: 3
    targetResourceType: 'Microsoft.ContainerService/managedClusters'
    windowSize: 'PT1M'
  }
  dependsOn: [
    omsContainerInsights
  ]
}

