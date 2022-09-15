targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('The flowLog\'s location')
@minLength(4)
param location string

@description('The flowLog\'s target resourceId')
@minLength(79)
param targetResourceId string

@description('The Id of the Log Analytics workspace that stores logs from the regional hub network')
@minLength(79)
param laHubId string

@description('The Id of the Storage account to store the flow logs')
@minLength(79)
param flowLogsStorageId string

/*** EXISTING RESOURCES ***/

resource networkWatcher 'Microsoft.Network/networkWatchers@2021-05-01' existing = {
  name: 'NetworkWatcher_${location}'
}

/*** RESOURCES ***/

resource flowlog 'Microsoft.Network/networkWatchers/flowLogs@2021-05-01' = {
  parent: networkWatcher
  name: 'fl${guid(targetResourceId)}'
  location: location
  properties: {
    targetResourceId: targetResourceId
    storageId: flowLogsStorageId
    enabled: true
    format: {
        version: 2
    }
    flowAnalyticsConfiguration: {
        networkWatcherFlowAnalyticsConfiguration: {
            enabled: true
            workspaceResourceId: laHubId
            trafficAnalyticsInterval: 10
        }
    }
    retentionPolicy: {
        days: 365
        enabled: true
    }
  }
}
