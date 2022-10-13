targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('The regional network spoke VNet Resource ID that the cluster will be joined to')
@minLength(79)
param targetVnetResourceId string

@description('Azure AD Group in the identified tenant that will be granted the highly privileged cluster-admin role.')
param clusterAdminAadGroupObjectId string

@description('Your AKS control plane Cluster API authentication tenant')
param k8sControlPlaneAuthorizationTenantId string

@description('The certificate data for app gateway TLS termination. It is base64')
param appGatewayListenerCertificate string

@description('The base 64 encoded AKS Ingress Controller public certificate (as .crt or .cer) to be stored in Azure Key Vault as secret and referenced by Azure Application Gateway as a trusted root certificate.')
param aksIngressControllerCertificate string

@allowed([
  'australiaeast'
  'canadacentral'
  'centralus'
  'eastus'
  'eastus2'
  'westus2'
  'francecentral'
  'germanywestcentral'
  'northeurope'
  'southafricanorth'
  'southcentralus'
  'uksouth'
  'westeurope'
  'japaneast'
  'southeastasia'
])
@description('AKS Service, Node Pools, and supporting services (KeyVault, App Gateway, etc) region. This needs to be the same region as the vnet provided in these parameters.')
@minLength(4)
param location string

@allowed([
  'australiasoutheast'
  'canadaeast'
  'eastus2'
  'westus'
  'centralus'
  'westcentralus'
  'francesouth'
  'germanynorth'
  'westeurope'
  'ukwest'
  'northeurope'
  'japanwest'
  'southafricawest'
  'northcentralus'
  'eastasia'
  'eastus'
  'westus2'
  'francecentral'
  'uksouth'
  'japaneast'
  'southeastasia'
])
@description('For Azure resources that support native geo-redunancy, provide the location the redundant service will have its secondary. Should be different than the location parameter and ideally should be a paired region - https://learn.microsoft.com/azure/best-practices-availability-paired-regions. This region does not need to support availability zones.')
@minLength(4)
param geoRedundancyLocation string

@description('The Azure resource ID of a VM image that will be used for the jump box.')
@minLength(70)
param jumpBoxImageResourceId string

@description('A cloud init file (starting with #cloud-config) as a base 64 encoded string used to perform image customization on the jump box VMs. Used for user-management in this context.')
@minLength(100)
param jumpBoxCloudInitAsBase64 string = '10.200.0.0/26'

/*** VARIABLES ***/

var subRgUniqueString = uniqueString('aks', subscription().subscriptionId, resourceGroup().id)
var clusterName = 'aks-${subRgUniqueString}'
var jumpBoxDefaultAdminUserName = uniqueString(clusterName, resourceGroup().id)

/*** EXISTING RESOURCE GROUP RESOURCES ***/

@description('Spoke resource group')
resource targetResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  scope: subscription()
  name: '${split(targetVnetResourceId,'/')[4]}'
}

@description('The Spoke virtual network')
resource targetVirtualNetwork 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  scope: targetResourceGroup
  name: '${last(split(targetVnetResourceId,'/'))}'

  // Spoke virutual network's subnet for application gateway
  resource snetApplicationGateway 'subnets' existing = {
    name: 'snet-applicationgateway'
  }

  // Spoke virutual network's subnet for all private endpoints
  resource snetPrivatelinkendpoints 'subnets' existing = {
    name: 'snet-privatelinkendpoints'
  }

  // spoke virtual network's subnet for managment ops
  resource snetManagmentOps 'subnets' existing = {
    name: 'snet-management-ops'
  }
}

/*** EXISTING SUBSCRIPTION RESOURCES ***/

@description('Built-in Azure RBAC role that must be applied to the kublet Managed Identity allowing it to further assign adding managed identities to the cluster\'s underlying VMSS.')
resource managedIdentityOperatorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'f1a07417-d97a-45cb-824c-7a7467783830'
  scope: subscription()
}

@description('Built-in Azure RBAC role that is applied a Key Vault to grant with metadata, certificates, keys and secrets read privileges. Granted to App Gateway\'s managed identity.')
resource keyVaultReaderRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '21090545-7ca7-4776-b22c-e363652d74d2'
  scope: subscription()
}

@description('Built-in Azure RBAC role that is applied to a Key Vault to grant with secrets content read privileges. Granted to both Key Vault and our workload\'s identity.')
resource keyVaultSecretsUserRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '4633458b-17de-408a-b874-0445c86b69e6'
  scope: subscription()
}

/*** RESOURCES ***/

@description('The control plane identity used by the cluster.')
resource miClusterControlPlane 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: 'mi-${clusterName}-controlplane'
  location: location
}

@description('The in-cluster ingress controller identity used by pod identity agent to acquire access tokens to read ssl certs from Azure KeyVault.')
resource miIngressController 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: 'mi-${clusterName}-ingresscontroller'
  location: location
}

@description('The regional load balancer identity used by your Application Gateway instance to acquire access tokens to read ssl certs and secrets from Azure KeyVault.')
resource miAppGateway 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: 'mi-appgateway'
  location: location
}

@description('Grant the cluster control plane managed identity with managed identity operator role permissions; this allows to assign compute with the ingress controller managed identity; this is required for Azure Pod Idenity.')
resource icMiClusterControlPlaneManagedIdentityOperatorRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: miIngressController
  name: guid(resourceGroup().id, miClusterControlPlane.name, managedIdentityOperatorRole.id)
  properties: {
    roleDefinitionId: managedIdentityOperatorRole.id
    principalId: miClusterControlPlane.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

@description('The secret storage management resource for the aks regulated cluster.')
resource kv 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: 'kv-${clusterName}'
  location: location
  properties: {
    accessPolicies: [
      {
        tenantId: miAppGateway.properties.tenantId
        objectId: miAppGateway.properties.principalId
        permissions: {
          secrets: [
            'get'
          ]
          certificates: [
            'get'
          ]
          keys: []
        }
      }
      {
        tenantId: miIngressController.properties.tenantId
        objectId: miIngressController.properties.principalId
        permissions: {
          secrets: [
            'get'
          ]
          certificates: [
            'get'
          ]
          keys: []
        }
      }
    ]
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableSoftDelete: true
  }

  // The internet facing Tls certificate to establish https connections between your clients and your regional load balancer
  resource kvsGatewaySslCert 'secrets' = {
    name: 'sslcert'
    properties: {
      value: appGatewayListenerCertificate
    }
  }

  // The aks regulated in-cluster Tls certificate to establish https connections between your regional load balancer and your ingress controller enabling e2e tls connections
  resource kvsAppGwIngressInternalAksIngressTls 'secrets' = {
    name: 'agw-ingress-incluster-aks-ingress-contoso-com-tls'
    properties: {
      value: aksIngressControllerCertificate
    }
  }
}

@description('Grant the Azure Application Gateway managed identity with key vault secrets user role permissions; this allows pulling secrets from key vault.')
resource kvMiAppGatewaySecretsUserRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: kv
  name: guid(resourceGroup().id, 'mi-appgateway', keyVaultSecretsUserRole.id)
  properties: {
    roleDefinitionId: keyVaultSecretsUserRole.id
    principalId: miAppGateway.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

@description('Grant the Azure Application Gateway managed identity with key vault reader role permissions; this allows pulling frontend and backend certificates.')
resource kvMiAppGatewayKeyVaultReader_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: kv
  name: guid(resourceGroup().id, 'mi-appgateway', keyVaultReaderRole.id)
  properties: {
    roleDefinitionId: keyVaultReaderRole.id
    principalId: miAppGateway.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

@description('The aks regulated cluster log analytics workspace.')
resource law 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: 'law-${clusterName}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 90
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource lawAllPrometheus 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = {
  parent: law
  name: 'AllPrometheus'
  properties: {
    eTag: '*'
    category: 'Prometheus'
    displayName: 'All collected Prometheus information'
    query: 'InsightsMetrics | where Namespace == "prometheus"'
    version: 1
  }
}

resource lawForbiddenReponsesOnIngress 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = {
  parent: law
  name: 'ForbiddenReponsesOnIngress'
  properties: {
    eTag: '*'
    category: 'Prometheus'
    displayName: 'Increase number of forbidden response on the Ingress Controller'
    query: 'let value = toscalar(InsightsMetrics | where Namespace == "prometheus" and Name == "nginx_ingress_controller_requests" | where parse_json(Tags).status == 403 | summarize Value = avg(Val) by bin(TimeGenerated, 5m) | summarize min = min(Value)); InsightsMetrics | where Namespace == "prometheus" and Name == "nginx_ingress_controller_requests" | where parse_json(Tags).status == 403 | summarize AggregatedValue = avg(Val)-value by bin(TimeGenerated, 5m) | order by TimeGenerated | render barchart'
    version: 1
  }
}

resource lawNodeRebootRequested 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = {
  parent: law
  name: 'NodeRebootRequested'
  properties: {
    eTag: '*'
    category: 'Prometheus'
    displayName: 'Nodes reboot required by kured'
    query: 'InsightsMetrics | where Namespace == "prometheus" and Name == "kured_reboot_required" | where Val > 0'
    version: 1
  }
}

resource omsContainerInsights 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'ContainerInsights(${law.name})'
  location: location
  properties: {
    workspaceResourceId: law.id
  }
  plan: {
    name: 'ContainerInsights(${law.name})'
    product: 'OMSGallery/ContainerInsights'
    promotionCode: ''
    publisher: 'Microsoft'
  }
}

resource omsVmInsights 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'VMInsights(${law.name})'
  location: location
  properties: {
    workspaceResourceId: law.id
  }
  plan: {
    name: 'VMInsights(${law.name})'
    product: 'OMSGallery/VMInsights'
    promotionCode: ''
    publisher: 'Microsoft'
  }
}

resource omsSecurityInsights 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'SecurityInsights(${law.name})'
  location: location
  properties: {
    workspaceResourceId: law.id
  }
  plan: {
    name: 'SecurityInsights(${law.name})'
    product: 'OMSGallery/SecurityInsights'
    promotionCode: ''
    publisher: 'Microsoft'
  }
}

resource miwSecurityInsights 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid(omsSecurityInsights.name)
  location: location
  tags: {
    'hidden-title': 'Azure Kubernetes Service (AKS) Security - ${law.name}'
  }
  kind: 'shared'
  properties: {
    displayName: 'Azure Kubernetes Service (AKS) Security - ${law.name}'
    serializedData: '{"version":"Notebook/1.0","items":[{"type":1,"content":{"json":"## AKS Security\\n"},"name":"text - 2"},{"type":9,"content":{"version":"KqlParameterItem/1.0","crossComponentResources":["{workspaces}"],"parameters":[{"id":"311d3728-7f8a-4b16-8a34-097d099323d5","version":"KqlParameterItem/1.0","name":"subscription","label":"Subscription","type":6,"isRequired":true,"multiSelect":true,"quote":"\'","delimiter":",","value":[],"typeSettings":{"additionalResourceOptions":[],"includeAll":false,"showDefault":false}},{"id":"3a56d260-4fb9-46d6-b121-cea854104c91","version":"KqlParameterItem/1.0","name":"workspaces","label":"Workspaces","type":5,"isRequired":true,"multiSelect":true,"quote":"\'","delimiter":",","query":"where type =~ \'microsoft.operationalinsights/workspaces\'\\r\\n| where strcat(\'/subscriptions/\',subscriptionId) in ({subscription})\\r\\n| project id","crossComponentResources":["{subscription}"],"typeSettings":{"additionalResourceOptions":["value::all"]},"queryType":1,"resourceType":"microsoft.resourcegraph/resources","value":["value::all"]},{"id":"9615cea6-c661-470a-b4ae-1aab8ae6f448","version":"KqlParameterItem/1.0","name":"clustername","label":"Cluster name","type":5,"isRequired":true,"multiSelect":true,"quote":"\'","delimiter":",","query":"where type == \\"microsoft.containerservice/managedclusters\\"\\r\\n| where strcat(\'/subscriptions/\',subscriptionId) in ({subscription})\\r\\n| distinct tolower(id)","crossComponentResources":["{subscription}"],"value":["value::all"],"typeSettings":{"resourceTypeFilter":{"microsoft.containerservice/managedclusters":true},"additionalResourceOptions":["value::all"],"showDefault":false},"timeContext":{"durationMs":86400000},"queryType":1,"resourceType":"microsoft.resourcegraph/resources"},{"id":"236c00ec-1493-4e60-927a-a18b8b120cd5","version":"KqlParameterItem/1.0","name":"timeframe","label":"Time range","type":4,"description":"Time","isRequired":true,"value":{"durationMs":172800000},"typeSettings":{"selectableValues":[{"durationMs":300000},{"durationMs":900000},{"durationMs":1800000},{"durationMs":3600000},{"durationMs":14400000},{"durationMs":43200000},{"durationMs":86400000},{"durationMs":172800000},{"durationMs":259200000},{"durationMs":604800000},{"durationMs":1209600000},{"durationMs":2419200000},{"durationMs":2592000000},{"durationMs":5184000000},{"durationMs":7776000000}],"allowCustom":true},"timeContext":{"durationMs":86400000}},{"id":"bf0a3e4f-fff9-450c-b9d3-c8c1dded9787","version":"KqlParameterItem/1.0","name":"nodeRgDetails","type":1,"query":"where type == \\"microsoft.containerservice/managedclusters\\"\\r\\n| where tolower(id) in ({clustername})\\r\\n| project nodeRG = properties.nodeResourceGroup, subscriptionId, id = toupper(id)\\r\\n| project nodeRgDetails = strcat(\'\\"\', nodeRG, \\";\\", subscriptionId, \\";\\", id, \'\\"\')","crossComponentResources":["value::all"],"isHiddenWhenLocked":true,"timeContext":{"durationMs":86400000},"queryType":1,"resourceType":"microsoft.resourcegraph/resources"},{"id":"df53126c-c40f-43d5-b99f-97ee3785c086","version":"KqlParameterItem/1.0","name":"diagnosticClusters","type":1,"query":"union withsource=_TableName *\\r\\n| where _TableName == \\"AzureDiagnostics\\" and Category == \\"kube-audit\\"\\r\\n| summarize diagnosticClusters = dcount(ResourceId)\\r\\n| project isDiagnosticCluster = iff(diagnosticClusters > 0, \\"yes\\", \\"no\\")","crossComponentResources":["{workspaces}"],"isHiddenWhenLocked":true,"timeContext":{"durationMs":172800000},"timeContextFromParameter":"timeframe","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces"}],"style":"pills","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces"},"name":"parameters - 3"},{"type":11,"content":{"version":"LinkItem/1.0","style":"tabs","links":[{"id":"07cf87dc-8234-47db-850d-ec41b2687b2a","cellValue":"mainTab","linkTarget":"parameter","linkLabel":"Microsoft Defender for Kubernetes","subTarget":"alerts","preText":"","style":"link"},{"id":"44033ee6-d83e-4253-a732-c258ef1da545","cellValue":"mainTab","linkTarget":"parameter","linkLabel":"Analytics over Diagnostic logs","subTarget":"diagnostics","style":"link"}]},"name":"links - 22"},{"type":12,"content":{"version":"NotebookGroup/1.0","groupType":"editable","items":[{"type":1,"content":{"json":"## Microsoft Defender for AKS coverage"},"name":"text - 10"},{"type":3,"content":{"version":"KqlItem/1.0","query":"datatable (Event:string)\\r\\n    [\\"AKS Workbook\\"]\\r\\n| extend cluster = (strcat(\\"[\\", \\"{clustername}\\", \\"]\\"))\\r\\n| extend cluster = todynamic(replace(\\"\'\\", \'\\"\', cluster))\\r\\n| mvexpand cluster\\r\\n| extend subscriptionId = extract(@\\"/subscriptions/([^/]+)\\", 1, tostring(cluster))\\r\\n| summarize AksClusters = count() by subscriptionId, DefenderForAks = 0\\r\\n| union\\r\\n(\\r\\nsecurityresources\\r\\n| where type =~ \\"microsoft.security/pricings\\"\\r\\n| where name == \\"KubernetesService\\"\\r\\n| project DefenderForAks = iif(properties.pricingTier == \'Standard\', 1, 0), AksClusters = 0, subscriptionId\\r\\n)\\r\\n| summarize AksClusters = sum(AksClusters), DefenderForAks = sum(DefenderForAks) by subscriptionId\\r\\n| project Subscription = strcat(\'/subscriptions/\', subscriptionId), [\\"AKS clusters\\"] = AksClusters, [\'Defender for AKS\'] = iif(DefenderForAks > 0,\'yes\',\'no\'), [\'Onboard Microsoft Defender\'] = iif(DefenderForAks > 0, \'\', \'https://ms.portal.azure.com/#blade/Microsoft_Azure_Security/SecurityMenuBlade/26\')\\r\\n| order by [\'Defender for AKS\'] asc","size":0,"queryType":1,"resourceType":"microsoft.resourcegraph/resources","crossComponentResources":["{subscription}"],"gridSettings":{"formatters":[{"columnMatch":"Defender for AKS","formatter":18,"formatOptions":{"thresholdsOptions":"icons","thresholdsGrid":[{"operator":"==","thresholdValue":"no","representation":"4","text":""},{"operator":"Default","thresholdValue":null,"representation":"success","text":""}]}},{"columnMatch":"Onboard Microsoft Defender","formatter":7,"formatOptions":{"linkTarget":"Url","linkLabel":""}}]}},"customWidth":"66","name":"query - 9"},{"type":3,"content":{"version":"KqlItem/1.0","query":"datatable (Event:string)\\r\\n    [\\"AKS Workbook\\"]\\r\\n| extend cluster = (strcat(\\"[\\", \\"{clustername}\\", \\"]\\"))\\r\\n| extend cluster = todynamic(replace(\\"\'\\", \'\\"\', cluster))\\r\\n| mvexpand cluster\\r\\n| extend subscriptionId = extract(@\\"/subscriptions/([^/]+)\\", 1, tostring(cluster))\\r\\n| summarize AksClusters = count() by subscriptionId, DefenderForAks = 0\\r\\n| union\\r\\n(\\r\\nsecurityresources\\r\\n| where type =~ \\"microsoft.security/pricings\\"\\r\\n| where name == \\"KubernetesService\\"\\r\\n| project DefenderForAks = iif(properties.pricingTier == \'Standard\', 1, 0), AksClusters = 0, subscriptionId\\r\\n)\\r\\n| summarize AksClusters = sum(AksClusters), DefenderForAks = sum(DefenderForAks) by subscriptionId\\r\\n| project Subscription = 1, [\'Defender for AKS\'] = iif(DefenderForAks > 0,\'Protected by Microsoft Defender\',\'Not protected by Microsoft Defender\')","size":0,"queryType":1,"resourceType":"microsoft.resourcegraph/resources","crossComponentResources":["{subscription}"],"visualization":"piechart"},"customWidth":"33","name":"query - 11"},{"type":1,"content":{"json":"### AKS alerts overview"},"name":"text - 21"},{"type":3,"content":{"version":"KqlItem/1.0","query":"SecurityAlert \\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where TimeGenerated {timeframe}\\r\\n| where AlertType startswith \\"AKS_\\"\\r\\n| project image = tostring(todynamic(ExtendedProperties)[\\"Container image\\"]), AlertType\\r\\n| where image != \\"\\"\\r\\n| summarize AlertTypes = dcount(AlertType) by image\\r\\n| where AlertTypes > 1\\r\\n//| render piechart \\r\\n","size":4,"title":"Images with multiple alerts","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"visualization":"tiles","tileSettings":{"showBorder":false,"titleContent":{"columnMatch":"image","formatter":1},"leftContent":{"columnMatch":"AlertTypes","formatter":12,"formatOptions":{"palette":"auto"},"numberFormat":{"unit":17,"options":{"maximumSignificantDigits":3,"maximumFractionDigits":2}}}}},"customWidth":"33","name":"query - 12"},{"type":3,"content":{"version":"KqlItem/1.0","query":"SecurityAlert \\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where TimeGenerated {timeframe}\\r\\n| where AlertType startswith \\"AKS_\\"\\r\\n| project AlertType, name = extract(@\\"/MICROSOFT.CONTAINERSERVICE/MANAGEDCLUSTERS/(.+)\\", 1, ResourceId)\\r\\n| summarize AlertTypes = dcount(AlertType)  by  name\\r\\n| where AlertTypes > 1\\r\\n","size":4,"title":"Clusters with multiple alert types","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"visualization":"tiles","tileSettings":{"showBorder":false,"titleContent":{"columnMatch":"name","formatter":1},"leftContent":{"columnMatch":"AlertTypes","formatter":12,"formatOptions":{"palette":"auto"},"numberFormat":{"unit":17,"options":{"maximumSignificantDigits":3,"maximumFractionDigits":2}}}}},"customWidth":"33","name":"query - 12 - Copy"},{"type":3,"content":{"version":"KqlItem/1.0","query":"SecurityAlert \\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where TimeGenerated {timeframe}\\r\\n| where AlertType startswith \\"AKS_\\"\\r\\n| project AlertType, name = extract(@\\"/MICROSOFT.CONTAINERSERVICE/MANAGEDCLUSTERS/(.+)\\", 1, ResourceId)\\r\\n| summarize count() by name\\r\\n\\r\\n","size":4,"title":"Alerts triggered by cluster","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"visualization":"tiles","tileSettings":{"showBorder":false,"titleContent":{"columnMatch":"name","formatter":1},"leftContent":{"columnMatch":"count_","formatter":12,"formatOptions":{"palette":"auto"},"numberFormat":{"unit":17,"options":{"maximumSignificantDigits":3,"maximumFractionDigits":2}}}}},"customWidth":"33","name":"query - 12 - Copy - Copy"},{"type":1,"content":{"json":"### Seucirty alerts details\\r\\n\\r\\nTo filter, press on the severities below.\\r\\nYou can also filter based on a specific resource."},"name":"text - 18"},{"type":3,"content":{"version":"KqlItem/1.0","query":"SecurityAlert\\r\\n| where TimeGenerated {timeframe}\\r\\n| extend rg = extract(@\\"/resourcegroups/([^/]+)\\", 1, tolower(ResourceId))\\r\\n| extend sub = extract(@\\"/subscriptions/([^/]+)\\", 1, tolower(ResourceId))\\r\\n| extend nodesDetailsArr = todynamic(\'{nodeRgDetails}\')\\r\\n| mv-expand singleNodeDetails = nodesDetailsArr\\r\\n| extend singleNodeArr = split(singleNodeDetails, \\";\\")\\r\\n| where tolower(singleNodeArr[0]) == rg and tolower(singleNodeArr[1]) == sub\\r\\n| project AlertSeverity\\r\\n| union\\r\\n(\\r\\nSecurityAlert \\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where TimeGenerated {timeframe}\\r\\n| where AlertType startswith \\"AKS_\\"\\r\\n| project AlertSeverity\\r\\n)\\r\\n| summarize count() by AlertSeverity","size":0,"title":"Alerts by severity","exportMultipleValues":true,"exportedParameters":[{"fieldName":"AlertSeverity","parameterName":"severity","parameterType":1,"quote":""}],"queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"visualization":"tiles","tileSettings":{"showBorder":false,"titleContent":{"columnMatch":"AlertSeverity","formatter":1},"leftContent":{"columnMatch":"count_","formatter":12,"formatOptions":{"palette":"auto"},"numberFormat":{"unit":17,"options":{"maximumSignificantDigits":3,"maximumFractionDigits":2}}}}},"customWidth":"11","name":"Alerts by severity"},{"type":3,"content":{"version":"KqlItem/1.0","query":"SecurityAlert\\r\\n| where TimeGenerated {timeframe}\\r\\n| where \\"{severity}\\" has AlertSeverity or isempty(\\"{severity}\\")\\r\\n| extend rg = extract(@\\"/resourcegroups/([^/]+)\\", 1, tolower(ResourceId))\\r\\n| extend sub = extract(@\\"/subscriptions/([^/]+)\\", 1, tolower(ResourceId))\\r\\n| extend nodesDetailsArr = todynamic(\'{nodeRgDetails}\')\\r\\n| mv-expand singleNodeDetails = nodesDetailsArr\\r\\n| extend singleNodeArr = split(singleNodeDetails, \\";\\")\\r\\n| where tolower(singleNodeArr[0]) == rg and tolower(singleNodeArr[1]) == sub\\r\\n| project ResourceId\\r\\n| union\\r\\n(\\r\\nSecurityAlert \\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where \\"{severity}\\" has AlertSeverity or isempty(\\"{severity}\\")\\r\\n| where TimeGenerated {timeframe}\\r\\n| where AlertType startswith \\"AKS_\\"\\r\\n| project ResourceId\\r\\n)\\r\\n| summarize Alerts = count() by ResourceId\\r\\n| order by Alerts desc\\r\\n| limit 10","size":0,"title":"Resources with most alerts","exportFieldName":"ResourceId","exportParameterName":"selectedResource","exportDefaultValue":"not_selected","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"gridSettings":{"formatters":[{"columnMatch":"Alerts","formatter":4,"formatOptions":{"palette":"red"}}]}},"customWidth":"22","name":"Resources with most alerts"},{"type":3,"content":{"version":"KqlItem/1.0","query":"\\r\\nSecurityAlert\\r\\n| where TimeGenerated {timeframe}\\r\\n| where \\"{severity}\\" has AlertSeverity or isempty(\\"{severity}\\")\\r\\n| extend rg = extract(@\\"/resourcegroups/([^/]+)\\", 1, tolower(ResourceId))\\r\\n| extend sub = extract(@\\"/subscriptions/([^/]+)\\", 1, tolower(ResourceId))\\r\\n| extend nodesDetailsArr = todynamic(\'{nodeRgDetails}\')\\r\\n| mv-expand singleNodeDetails = nodesDetailsArr\\r\\n| extend singleNodeArr = split(singleNodeDetails, \\";\\")\\r\\n| where tolower(singleNodeArr[0]) == rg and tolower(singleNodeArr[1]) == sub\\r\\n| extend AlertResourceType = \\"VM alerts\\"\\r\\n| union\\r\\n(\\r\\nSecurityAlert \\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where \\"{severity}\\" has AlertSeverity or isempty(\\"{severity}\\")\\r\\n| where TimeGenerated {timeframe}\\r\\n| where AlertType startswith \\"AKS_\\"\\r\\n| extend AlertResourceType = \\"Cluster alerts\\"\\r\\n)\\r\\n| summarize Alerts = count() by bin(TimeGenerated, {timeframe:grain}), AlertResourceType","size":0,"title":"Alerts over time","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"visualization":"timechart"},"customWidth":"66","name":"Alerts over time"},{"type":3,"content":{"version":"KqlItem/1.0","query":"SecurityAlert\\r\\n| where TimeGenerated {timeframe}\\r\\n| where \\"{severity}\\" has AlertSeverity or isempty(\\"{severity}\\")\\r\\n| extend rg = extract(@\\"/resourcegroups/([^/]+)\\", 1, tolower(ResourceId))\\r\\n| extend sub = extract(@\\"/subscriptions/([^/]+)\\", 1, tolower(ResourceId))\\r\\n| extend nodesDetailsArr = todynamic(\'{nodeRgDetails}\')\\r\\n| mv-expand singleNodeDetails = nodesDetailsArr\\r\\n| extend singleNodeArr = split(singleNodeDetails, \\";\\")\\r\\n| where tolower(singleNodeArr[0]) == rg and tolower(singleNodeArr[1]) == sub\\r\\n| where tolower(ResourceId) == tolower(\\"{selectedResource}\\") or \\"{selectedResource}\\" == \\"not_selected\\"\\r\\n| project [\\"Resource name\\"] = ResourceId, TimeGenerated, AlertSeverity, [\\"AKS cluster\\"] = toupper(singleNodeArr[2]), DisplayName, AlertLink\\r\\n| union\\r\\n(\\r\\nSecurityAlert\\r\\n| where TimeGenerated {timeframe}\\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where \\"{severity}\\" has AlertSeverity or isempty(\\"{severity}\\")\\r\\n| where AlertType startswith \\"AKS_\\"\\r\\n| where tolower(ResourceId) == tolower(\\"{selectedResource}\\") or \\"{selectedResource}\\" == \\"not_selected\\"\\r\\n| project [\\"Resource name\\"] = ResourceId, TimeGenerated, AlertSeverity, [\\"AKS cluster\\"] = ResourceId, DisplayName, AlertLink\\r\\n)\\r\\n| order by TimeGenerated asc","size":0,"title":"Microsoft Defender alerts","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"gridSettings":{"formatters":[{"columnMatch":"AlertLink","formatter":7,"formatOptions":{"linkTarget":"Url","linkLabel":"Go to alert "}}],"filter":true},"sortBy":[]},"name":"Microsoft Defender alerts","styleSettings":{"showBorder":true}}]},"conditionalVisibility":{"parameterName":"mainTab","comparison":"isEqualTo","value":"alerts"},"name":"Defender Alerts"},{"type":12,"content":{"version":"NotebookGroup/1.0","groupType":"editable","items":[{"type":1,"content":{"json":"## Diagnostic logs coverage"},"name":"text - 15"},{"type":3,"content":{"version":"KqlItem/1.0","query":"union withsource=_TableName *\\r\\n| where _TableName == \\"AzureDiagnostics\\" and Category == \\"kube-audit\\"\\r\\n| summarize count() by ResourceId = tolower(ResourceId)\\r\\n| summarize logsClusters = make_set(ResourceId)\\r\\n| extend selectedClusters = \\"[{clustername}]\\"\\r\\n| extend selectedClusters = replace(\\"\'\\", \'\\"\', selectedClusters)\\r\\n| extend selectedClusters = todynamic(selectedClusters)\\r\\n| mv-expand clusterId = selectedClusters\\r\\n| project clusterId = toupper(tostring(clusterId)), [\\"Diagnostic logs\\"] = (logsClusters has tostring(clusterId))\\r\\n| extend [\\"Diagnostic settings\\"] = iff([\\"Diagnostic logs\\"] == false, strcat(\\"https://ms.portal.azure.com/#@microsoft.onmicrosoft.com/resource\\", clusterId, \\"/diagnostics\\"), \\"\\")\\r\\n","size":0,"timeContext":{"durationMs":172800000},"timeContextFromParameter":"timeframe","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"gridSettings":{"formatters":[{"columnMatch":"Diagnostic logs","formatter":18,"formatOptions":{"thresholdsOptions":"icons","thresholdsGrid":[{"operator":"==","thresholdValue":"false","representation":"critical","text":""},{"operator":"Default","thresholdValue":null,"representation":"success","text":""}]}},{"columnMatch":"Diagnostic settings","formatter":7,"formatOptions":{"linkTarget":"Url"}}],"filter":true,"sortBy":[{"itemKey":"$gen_thresholds_Diagnostic logs_1","sortOrder":2}]},"sortBy":[{"itemKey":"$gen_thresholds_Diagnostic logs_1","sortOrder":2}]},"customWidth":"66","name":"query - 14"},{"type":3,"content":{"version":"KqlItem/1.0","query":"union withsource=_TableName *\\r\\n| where _TableName == \\"AzureDiagnostics\\" and Category == \\"kube-audit\\"\\r\\n| summarize count() by ResourceId = tolower(ResourceId)\\r\\n| summarize logsClusters = make_set(ResourceId)\\r\\n| extend selectedClusters = \\"[{clustername}]\\"\\r\\n| extend selectedClusters = replace(\\"\'\\", \'\\"\', selectedClusters)\\r\\n| extend selectedClusters = todynamic(selectedClusters)\\r\\n| mv-expand clusterId = selectedClusters\\r\\n| project clusterId = toupper(tostring(clusterId)), hasDiagnosticLogs = (logsClusters has tostring(clusterId))\\r\\n| summarize [\\"number of clusters\\"] = count() by hasDiagnosticLogs\\r\\n| extend hasDiagnosticLogs = iff(hasDiagnosticLogs == true, \\"Clusters with Diagnostic logs\\", \\"Clusters without Diagnostic logs\\")\\r\\n","size":0,"timeContext":{"durationMs":172800000},"timeContextFromParameter":"timeframe","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"visualization":"piechart"},"customWidth":"33","name":"query - 17"},{"type":12,"content":{"version":"NotebookGroup/1.0","groupType":"editable","items":[{"type":1,"content":{"json":"## Cluster operations"},"name":"text - 16"},{"type":11,"content":{"version":"LinkItem/1.0","style":"tabs","links":[{"id":"3f616701-fd4b-482c-aff1-a85414daa05c","cellValue":"dispalyedGraph","linkTarget":"parameter","linkLabel":"Masterclient operations","subTarget":"masterclient","preText":"","style":"link"},{"id":"e6fa55f1-7d57-4f5e-8e83-429740853731","cellValue":"dispalyedGraph","linkTarget":"parameter","linkLabel":"Pod creation operations","subTarget":"podCreation","style":"link"},{"id":"f4c46251-0090-4ca3-a81c-0686bff3ff35","cellValue":"dispalyedGraph","linkTarget":"parameter","linkLabel":"Secret get\\\\list operations","subTarget":"secretOperation","style":"link"}]},"name":"links - 11"},{"type":3,"content":{"version":"KqlItem/1.0","query":"AzureDiagnostics \\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where TimeGenerated {timeframe}\\r\\n| where Category == \\"kube-audit\\"\\r\\n| where log_s has \\"masterclient\\"\\r\\n| project TimeGenerated, parse_json(log_s), ResourceId\\r\\n| project TimeGenerated, ResourceId, username = tostring(log_s[\\"user\\"].username)\\r\\n| where username == \\"masterclient\\"\\r\\n| extend name = extract(@\\"/MICROSOFT.CONTAINERSERVICE/MANAGEDCLUSTERS/(.+)\\", 1, ResourceId)\\r\\n| summarize count() by name, bin(TimeGenerated, 1h)","size":0,"queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"visualization":"timechart","tileSettings":{"showBorder":false,"titleContent":{"columnMatch":"name","formatter":1},"leftContent":{"columnMatch":"count_","formatter":12,"formatOptions":{"palette":"auto"},"numberFormat":{"unit":17,"options":{"maximumSignificantDigits":3,"maximumFractionDigits":2}}}},"chartSettings":{"yAxis":["count_"]}},"conditionalVisibility":{"parameterName":"dispalyedGraph","comparison":"isEqualTo","value":"masterclient"},"name":"Masterclient operations","styleSettings":{"showBorder":true}},{"type":3,"content":{"version":"KqlItem/1.0","query":"AzureDiagnostics\\r\\n| where Category == \\"kube-audit\\"\\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where TimeGenerated {timeframe}\\r\\n| where log_s has \\"pods\\"\\r\\n| project TimeGenerated, parse_json(log_s), ResourceId\\r\\n| project AzureResourceId = ResourceId, TimeGenerated,\\r\\n RequestURI = tostring(log_s[\\"requestURI\\"]),\\r\\n Verb = tostring(log_s[\\"verb\\"]),\\r\\n ObjectRef = log_s[\\"objectRef\\"],\\r\\n ResponseStatus = log_s[\\"responseStatus\\"]\\r\\n//Main query\\r\\n| where ObjectRef.resource == \\"pods\\" and Verb == \\"create\\" and ResponseStatus.code startswith \\"20\\"\\r\\n  and RequestURI endswith \\"/pods\\"\\r\\n| extend name = extract(@\\"/MICROSOFT.CONTAINERSERVICE/MANAGEDCLUSTERS/(.+)\\", 1, AzureResourceId)\\r\\n| summarize count() by name, bin(TimeGenerated, 1h)","size":0,"queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"visualization":"timechart"},"conditionalVisibility":{"parameterName":"dispalyedGraph","comparison":"isEqualTo","value":"podCreation"},"name":"pods creation","styleSettings":{"showBorder":true}},{"type":3,"content":{"version":"KqlItem/1.0","query":"AzureDiagnostics\\r\\n| where Category == \\"kube-audit\\"\\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where TimeGenerated {timeframe}\\r\\n| where log_s has \\"secrets\\"\\r\\n| project TimeGenerated, parse_json(log_s), ResourceId\\r\\n| project AzureResourceId = ResourceId, TimeGenerated,\\r\\n RequestURI = tostring(log_s[\\"requestURI\\"]),\\r\\n Verb = tostring(log_s[\\"verb\\"]),\\r\\n ObjectRef = log_s[\\"objectRef\\"],\\r\\n ResponseStatus = log_s[\\"responseStatus\\"]\\r\\n//Main query\\r\\n| where ObjectRef.resource == \\"secrets\\" and (Verb == \\"list\\" or Verb == \\"get\\") and ResponseStatus.code startswith \\"20\\"\\r\\n| where ObjectRef.name != \\"tunnelfront\\" and ObjectRef.name != \\"tunnelend\\" and ObjectRef.name != \\"kubernetes-dashboard-key-holder\\"\\r\\n| extend name = extract(@\\"/MICROSOFT.CONTAINERSERVICE/MANAGEDCLUSTERS/(.+)\\", 1, AzureResourceId)\\r\\n| summarize count() by name, bin(TimeGenerated, 1h)","size":0,"timeContext":{"durationMs":172800000},"timeContextFromParameter":"timeframe","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"visualization":"timechart","gridSettings":{"sortBy":[{"itemKey":"count_","sortOrder":2}]},"sortBy":[{"itemKey":"count_","sortOrder":2}]},"conditionalVisibility":{"parameterName":"dispalyedGraph","comparison":"isEqualTo","value":"secretOperation"},"name":"secrets operation","styleSettings":{"showBorder":true}},{"type":3,"content":{"version":"KqlItem/1.0","query":"let ascAlerts = \\nunion withsource=_TableName *\\n| where _TableName == \\"SecurityAlert\\"\\n| where tolower(ResourceId) in ({clustername})\\n| where TimeGenerated {timeframe}\\n| extend AlertType = column_ifexists(\\"AlertType\\", \\"\\")\\n| where AlertType == \\"AKS_PrivilegedContainer\\"\\n| extend ExtendedProperties = column_ifexists(\\"ExtendedProperties\\", todynamic(\\"\\"))\\n| extend ExtendedProperties = parse_json(ExtendedProperties)\\n| extend AlertLink = column_ifexists(\\"AlertLink\\", \\"\\")\\n| summarize arg_min(TimeGenerated, AlertLink) by AzureResourceId = ResourceId, name = tostring(ExtendedProperties[\\"Pod name\\"]), podNamespace =  tostring(ExtendedProperties[\\"Namespace\\"])\\n;\\nlet podOperations = AzureDiagnostics\\n| where Category == \\"kube-audit\\"\\n| where tolower(ResourceId) in ({clustername})\\n| where TimeGenerated {timeframe}\\n| where log_s has \\"privileged\\"\\n| project TimeGenerated, parse_json(log_s), ResourceId\\n| project AzureResourceId = ResourceId, TimeGenerated,\\n RequestURI = tostring(log_s[\\"requestURI\\"]),\\n Verb = tostring(log_s[\\"verb\\"]),\\n ObjectRef = log_s[\\"objectRef\\"],\\n RequestObject = log_s[\\"requestObject\\"],\\n ResponseStatus = log_s[\\"responseStatus\\"],\\n ResponseObject = log_s[\\"responseObject\\"]\\n//Main query\\n| where ObjectRef.resource == \\"pods\\" and Verb == \\"create\\" and ResponseStatus.code startswith \\"20\\" and RequestObject has \\"privileged\\"\\n  and RequestURI endswith \\"/pods\\"\\n| extend containers = RequestObject.spec.containers\\n| mvexpand containers\\n| where containers.securityContext.privileged == true\\n| summarize TimeGenerated = min(TimeGenerated) by\\n            name = tostring(ResponseObject.metadata.name),\\n            podNamespace = tostring(ResponseObject.metadata.namespace),\\n            imageName = tostring(containers.image),\\n            containerName = tostring(containers.name),\\n            AzureResourceId\\n| extend id = strcat(name,\\";\\", AzureResourceId)\\n| extend parent = AzureResourceId\\n| join kind=leftouter (ascAlerts) on AzureResourceId, name, podNamespace\\n;\\nlet cached = materialize(podOperations)\\n;\\nlet clusters = cached | distinct AzureResourceId\\n;\\n// Main query\\ncached\\n| union\\n(\\nclusters\\n| project \\n            name = AzureResourceId,\\n            id = AzureResourceId,\\n            parent = \\"\\"      \\n)\\n| project-away name1, podNamespace1, TimeGenerated1","size":1,"title":"Privileged containers creation","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"visualization":"table","gridSettings":{"formatters":[{"columnMatch":"name","formatter":13,"formatOptions":{"linkTarget":null,"showIcon":true}},{"columnMatch":"AzureResourceId","formatter":5},{"columnMatch":"id","formatter":5},{"columnMatch":"parent","formatter":5},{"columnMatch":"AlertLink","formatter":7,"formatOptions":{"linkTarget":"Url","linkLabel":""}}],"hierarchySettings":{"idColumn":"id","parentColumn":"parent","treeType":0,"expanderColumn":"name"}},"sortBy":[]},"customWidth":"66","name":"Privileged container","styleSettings":{"showBorder":true}},{"type":3,"content":{"version":"KqlItem/1.0","query":"SecurityAlert \\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where TimeGenerated {timeframe}\\r\\n| where AlertType == \\"AKS_PrivilegedContainer\\"\\r\\n| project name = extract(@\\"/MICROSOFT.CONTAINERSERVICE/MANAGEDCLUSTERS/(.+)\\", 1, ResourceId)\\r\\n| summarize alert = count() by name","size":1,"title":"AKS clusters with related Microsoft Defender alerts","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"visualization":"piechart","tileSettings":{"showBorder":false,"titleContent":{"columnMatch":"name","formatter":1},"leftContent":{"columnMatch":"alert","formatter":12,"formatOptions":{"palette":"auto"},"numberFormat":{"unit":17,"options":{"maximumSignificantDigits":3,"maximumFractionDigits":2}}}},"graphSettings":{"type":0,"topContent":{"columnMatch":"name","formatter":1},"centerContent":{"columnMatch":"alert","formatter":1,"numberFormat":{"unit":17,"options":{"maximumSignificantDigits":3,"maximumFractionDigits":2}}}}},"customWidth":"33","name":"query - 7","styleSettings":{"showBorder":true}},{"type":3,"content":{"version":"KqlItem/1.0","query":"let baseQuery = AzureDiagnostics \\r\\n| where Category == \\"kube-audit\\"\\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where TimeGenerated {timeframe}\\r\\n| where log_s has \\"exec\\"\\r\\n| project TimeGenerated, parse_json(log_s), ResourceId\\r\\n| project TimeGenerated,\\r\\n          AzureResourceId = ResourceId,\\r\\n          User = log_s[\\"user\\"],\\r\\n          StageTimestamp = todatetime(log_s[\\"stageTimestamp\\"]),\\r\\n          Timestamp = todatetime(log_s[\\"timestamp\\"]),\\r\\n          Stage = tostring(log_s[\\"stage\\"]),\\r\\n          RequestURI = tostring(log_s[\\"requestURI\\"]),\\r\\n          UserAgent = tostring(log_s[\\"userAgent\\"]),\\r\\n          Verb = tostring(log_s[\\"verb\\"]),\\r\\n          ObjectRef = log_s[\\"objectRef\\"],\\r\\n          ResponseStatus = log_s[\\"responseStatus\\"]\\r\\n| where ObjectRef.resource == \\"pods\\" and Verb == \\"create\\" and ResponseStatus.code == 101 and ObjectRef.subresource == \\"exec\\"\\r\\n| project operationTime = TimeGenerated,\\r\\n          RequestURI,\\r\\n          podName       = tostring(ObjectRef.name),\\r\\n          podNamespace  = tostring(ObjectRef.namespace),\\r\\n          username      = tostring(User.username),\\r\\n          AzureResourceId\\r\\n// Parse the exec command\\r\\n| extend commands =  extractall(@\\"command=([^\\\\&]*)\\", RequestURI)\\r\\n| extend commandsStr = url_decode(strcat_array(commands, \\" \\"))\\r\\n| project-away [\'commands\'], RequestURI\\r\\n| where username != \\"aksProblemDetector\\"\\r\\n;\\r\\nlet cached = materialize(baseQuery);\\r\\nlet execOperations = \\r\\ncached\\r\\n| summarize operationTime = min(operationTime), numberOfPerations = count() by name = commandsStr, username, podNamespace, podName, AzureResourceId\\r\\n| extend id = name\\r\\n| extend parentId = podName\\r\\n| project id, parentId, name, operationTime, numberOfPerations, podNamespace, username, AzureResourceId\\r\\n;\\r\\nlet podOperations = \\r\\ncached\\r\\n| summarize operationTime = min(operationTime), numberOfPerations = count() by name = podName, podNamespace, AzureResourceId\\r\\n| extend id = name\\r\\n| extend parentId = AzureResourceId\\r\\n| project id, parentId, name, operationTime, numberOfPerations, podNamespace, username = \\"\\", AzureResourceId\\r\\n;\\r\\nlet clusterOperations = \\r\\ncached\\r\\n| summarize operationTime = min(operationTime), numberOfPerations = count() by name = AzureResourceId\\r\\n| extend id = name\\r\\n| extend parentId = \\"\\"\\r\\n| project id, parentId, name, operationTime, numberOfPerations, username = \\"\\", podNamespace = \\"\\", AzureResourceId = name\\r\\n;\\r\\nunion clusterOperations, podOperations, execOperations","size":1,"title":"exec commands","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"visualization":"table","gridSettings":{"formatters":[{"columnMatch":"id","formatter":5},{"columnMatch":"parentId","formatter":5},{"columnMatch":"numberOfPerations","formatter":4,"formatOptions":{"palette":"blue","compositeBarSettings":{"labelText":"","columnSettings":[]}}},{"columnMatch":"AzureResourceId","formatter":5}],"hierarchySettings":{"idColumn":"id","parentColumn":"parentId","treeType":0,"expanderColumn":"name","expandTopLevel":false}}},"customWidth":"33","name":"exec commands","styleSettings":{"showBorder":true}},{"type":3,"content":{"version":"KqlItem/1.0","query":"SecurityAlert \\r\\n| where AlertType == \\"AKS_MaliciousContainerExec\\"\\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where TimeGenerated {timeframe}\\r\\n| project TimeGenerated, ResourceId, ExtendedProperties = todynamic(ExtendedProperties)\\r\\n| project TimeGenerated, ResourceId, [\\"Pod name\\"] = ExtendedProperties[\\"Pod name\\"], Command = ExtendedProperties[\\"Command\\"]","size":1,"title":"Related Microsoft Defender alerts details","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"gridSettings":{"sortBy":[{"itemKey":"TimeGenerated","sortOrder":1}]},"sortBy":[{"itemKey":"TimeGenerated","sortOrder":1}]},"customWidth":"33","name":"query - 9","styleSettings":{"showBorder":true}},{"type":3,"content":{"version":"KqlItem/1.0","query":"SecurityAlert \\r\\n| where AlertType == \\"AKS_MaliciousContainerExec\\"\\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where TimeGenerated {timeframe}\\r\\n| project name = extract(@\\"/MICROSOFT.CONTAINERSERVICE/MANAGEDCLUSTERS/(.+)\\", 1, ResourceId)\\r\\n| summarize alert = count() by name","size":1,"title":"AKS clusters with related Microsoft Defender alerts","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"visualization":"piechart"},"customWidth":"33","name":"query - 8","styleSettings":{"showBorder":true}},{"type":3,"content":{"version":"KqlItem/1.0","query":"let ascAlerts = \\r\\nunion withsource=_TableName *\\r\\n| where _TableName == \\"SecurityAlert\\"\\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where TimeGenerated {timeframe}\\r\\n| extend AlertType = column_ifexists(\\"AlertType\\", \\"\\")\\r\\n| where AlertType == \\"AKS_SensitiveMount\\"\\r\\n| extend ExtendedProperties = column_ifexists(\\"ExtendedProperties\\", todynamic(\\"\\"))\\r\\n| extend ExtendedProperties = parse_json(ExtendedProperties)\\r\\n| extend AlertLink = column_ifexists(\\"AlertLink\\", \\"\\")\\r\\n| summarize arg_min(TimeGenerated, AlertLink) by AzureResourceId = ResourceId, containerName = tostring(ExtendedProperties[\\"Container name\\"]), mountPath = tostring(ExtendedProperties[\\"Sensitive mount path\\"])\\r\\n;\\r\\nlet podOperations = \\r\\nAzureDiagnostics \\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where TimeGenerated {timeframe}\\r\\n| where Category == \\"kube-audit\\"\\r\\n| where log_s has \\"hostPath\\"\\r\\n| project TimeGenerated, parse_json(log_s), ResourceId\\r\\n//Parsing\\r\\n| project AzureResourceId = ResourceId, TimeGenerated,\\r\\n Verb = tostring(log_s[\\"verb\\"]),\\r\\n ObjectRef = log_s[\\"objectRef\\"],\\r\\n RequestObject = log_s[\\"requestObject\\"],\\r\\n ResponseStatus = log_s[\\"responseStatus\\"],\\r\\n ResponseObject = log_s[\\"responseObject\\"]\\r\\n//\\r\\n//Main query\\r\\n//\\r\\n| where ObjectRef.resource == \\"pods\\" and Verb == \\"create\\" and ResponseStatus.code startswith \\"20\\" and RequestObject has \\"hostPath\\"\\r\\n| extend volumes = RequestObject.spec.volumes\\r\\n| mvexpand volumes\\r\\n| extend mountPath = volumes.hostPath.path\\r\\n| where mountPath != \\"\\" \\r\\n| extend container = RequestObject.spec.containers\\r\\n| mvexpand container\\r\\n| extend  detectionTime = TimeGenerated\\r\\n| project detectionTime,\\r\\n          podName = ResponseObject.metadata.name,\\r\\n          podNamespace = ResponseObject.metadata.namespace,\\r\\n          containerName = container.name,\\r\\n          containerImage = container.image,\\r\\n          mountPath,\\r\\n          mountName = volumes.name,\\r\\n          AzureResourceId,\\r\\n          container\\r\\n| extend volumeMounts = container.volumeMounts\\r\\n| mv-expand volumeMounts\\r\\n| where tostring(volumeMounts.name) == tostring(mountName)\\r\\n| summarize operationTime = min(detectionTime) by AzureResourceId, name = tostring(podName),tostring(podNamespace), tostring(containerName), tostring(containerImage), tostring(mountPath), tostring(mountName)\\r\\n| extend id = strcat(name, \\";\\", AzureResourceId)\\r\\n| extend parent = AzureResourceId\\r\\n| join kind=leftouter (ascAlerts) on AzureResourceId, containerName, mountPath\\r\\n;\\r\\nlet cached = materialize(podOperations)\\r\\n;\\r\\nlet clusters = cached | distinct AzureResourceId\\r\\n;\\r\\n// Main query\\r\\ncached\\r\\n| union\\r\\n(\\r\\nclusters\\r\\n| project \\r\\n            name = toupper(AzureResourceId),\\r\\n            id = AzureResourceId,\\r\\n            parent = \\"\\"      \\r\\n)\\r\\n| project-away containerName1, mountPath1, TimeGenerated\\r\\n","size":1,"title":"hostPath mount","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"gridSettings":{"formatters":[{"columnMatch":"AzureResourceId","formatter":5},{"columnMatch":"name","formatter":13,"formatOptions":{"linkTarget":null,"showIcon":true}},{"columnMatch":"id","formatter":5},{"columnMatch":"parent","formatter":5},{"columnMatch":"AzureResourceId1","formatter":5},{"columnMatch":"AlertLink","formatter":7,"formatOptions":{"linkTarget":"Url"}}],"hierarchySettings":{"idColumn":"id","parentColumn":"parent","treeType":0,"expanderColumn":"name"}},"sortBy":[]},"customWidth":"66","name":"query - 10","styleSettings":{"showBorder":true}},{"type":3,"content":{"version":"KqlItem/1.0","query":"SecurityAlert \\r\\n| where AlertType == \\"AKS_SensitiveMount\\"\\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where TimeGenerated {timeframe}\\r\\n| project name = extract(@\\"/MICROSOFT.CONTAINERSERVICE/MANAGEDCLUSTERS/(.+)\\", 1, ResourceId)\\r\\n| summarize alert = count() by name","size":1,"title":"AKS clusters with related Microsoft Defender alerts","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"visualization":"piechart","sortBy":[]},"customWidth":"33","name":"query - 10","styleSettings":{"showBorder":true}},{"type":3,"content":{"version":"KqlItem/1.0","query":"let bindingOper = AzureDiagnostics\\r\\n| where Category == \\"kube-audit\\"\\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where TimeGenerated {timeframe}\\r\\n| where log_s has \\"clusterrolebindings\\"\\r\\n| project TimeGenerated, parse_json(log_s), ResourceId\\r\\n//Parsing\\r\\n| project AzureResourceId = ResourceId, TimeGenerated,\\r\\n RequestURI = tostring(log_s[\\"requestURI\\"]),\\r\\n User = log_s[\\"user\\"],\\r\\n Verb = tostring(log_s[\\"verb\\"]),\\r\\n ObjectRef = log_s[\\"objectRef\\"],\\r\\n RequestObject = log_s[\\"requestObject\\"],\\r\\n ResponseStatus = log_s[\\"responseStatus\\"]\\r\\n| where ObjectRef.resource == \\"clusterrolebindings\\" and Verb == \\"create\\" and ResponseStatus.code startswith \\"20\\" and RequestObject.roleRef.name == \\"cluster-admin\\"   \\r\\n| extend subjects = RequestObject.subjects\\r\\n| mv-expand subjects\\r\\n| project AzureResourceId, TimeGenerated, subjectName = tostring(subjects.name), subjectKind = tostring(subjects[\\"kind\\"]), bindingName = tostring(ObjectRef.name)\\r\\n| summarize operationTime = min(TimeGenerated) by AzureResourceId, subjectName, subjectKind, bindingName\\r\\n| extend id = strcat(subjectName, \\";\\", AzureResourceId)\\r\\n| extend parent = AzureResourceId\\r\\n;\\r\\nlet cached = materialize(bindingOper)\\r\\n;\\r\\nlet clusters = cached | distinct AzureResourceId\\r\\n;\\r\\n// Main query\\r\\ncached\\r\\n| union\\r\\n(\\r\\nclusters\\r\\n| project \\r\\n            name = AzureResourceId,\\r\\n            id = AzureResourceId,\\r\\n            parent = \\"\\"      \\r\\n)","size":1,"title":"Cluster-admin binding","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"visualization":"table","gridSettings":{"formatters":[{"columnMatch":"AzureResourceId","formatter":5},{"columnMatch":"id","formatter":5},{"columnMatch":"parent","formatter":5},{"columnMatch":"name","formatter":13,"formatOptions":{"linkTarget":null,"showIcon":true}}],"hierarchySettings":{"idColumn":"id","parentColumn":"parent","treeType":0,"expanderColumn":"name"}}},"customWidth":"66","name":"query - 5","styleSettings":{"showBorder":true}},{"type":3,"content":{"version":"KqlItem/1.0","query":"SecurityAlert \\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where TimeGenerated {timeframe}\\r\\n| where AlertType == \\"AKS_ClusterAdminBinding\\"\\r\\n| project name = extract(@\\"/MICROSOFT.CONTAINERSERVICE/MANAGEDCLUSTERS/(.+)\\", 1, ResourceId)\\r\\n| summarize count() by name","size":1,"title":"AKS clusters with related Microsoft Defender alerts","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"visualization":"piechart"},"customWidth":"33","name":"query - 11","styleSettings":{"showBorder":true}},{"type":3,"content":{"version":"KqlItem/1.0","query":"AzureDiagnostics\\r\\n| where Category == \\"kube-audit\\"\\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where TimeGenerated {timeframe}\\r\\n| where log_s has \\"events\\"\\r\\n| project TimeGenerated, parse_json(log_s), ResourceId\\r\\n//Parsing\\r\\n| project AzureResourceId = ResourceId, \\r\\n TimeGenerated,\\r\\n SourceIPs = tostring(log_s[\\"sourceIPs\\"][0]),\\r\\n User = log_s[\\"user\\"],\\r\\n Verb = tostring(log_s[\\"verb\\"]),\\r\\n ObjectRef = log_s[\\"objectRef\\"],\\r\\n ResponseStatus = log_s[\\"responseStatus\\"]\\r\\n| where ObjectRef.resource == \\"events\\" and Verb == \\"delete\\" and ResponseStatus.code == 200\\r\\n| project TimeGenerated, AzureResourceId, username = tostring(User.username), ipAddr = tostring(SourceIPs), \\r\\n          eventName = tostring(ObjectRef.name), eventNamespace = tostring(ObjectRef.namespace), status = tostring(ResponseStatus.code)\\r\\n| summarize operationTime = min(TimeGenerated), eventNames = make_set(eventName, 10) by\\r\\n                                        AzureResourceId, \\r\\n                                        eventNamespace,\\r\\n                                        username,\\r\\n                                        ipAddr\\r\\n// Format the list of the event names\\r\\n| extend eventNames = substring(eventNames, 1 , strlen(eventNames) - 2)\\r\\n| extend eventNames = replace(\'\\"\', \\"\\", eventNames)\\r\\n| extend eventNames = replace(\\",\\", \\", \\", eventNames)","size":1,"title":"Delete events","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"]},"name":"query - 6","styleSettings":{"showBorder":true}}]},"conditionalVisibility":{"parameterName":"diagnosticClusters","comparison":"isEqualTo","value":"yes"},"name":"diagnosticData"},{"type":1,"content":{"json":"No Diagnostic Logs data in the selected workspaces. \\r\\nTo enable Diagnostic Logs for your AKS cluster: Go to your AKS cluster --> Diagnostic settings --> Add diagnostic setting --> Select \\"kube-audit\\" and send the data to your workspace.\\r\\n\\r\\nGet more details here: https://learn.microsoft.com/azure/aks/view-master-logs","style":"info"},"conditionalVisibility":{"parameterName":"diagnosticClusters","comparison":"isEqualTo","value":"no"},"name":"text - 4"}]},"conditionalVisibility":{"parameterName":"mainTab","comparison":"isEqualTo","value":"diagnostics"},"name":"diagnostics"}],"fromTemplateId":"sentinel-AksWorkbook","$schema":"https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json"}'
    version: '1.0'
    category: 'sentinel'
    sourceId: law.id
    tags: [
      'AksSecurityWorkbook'
      '1.2'
    ]
  }
}

resource omsKeyVaultAnalytics 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'KeyVaultAnalytics(${law.name})'
  location: location
  properties: {
    workspaceResourceId: law.id
  }
  plan: {
    name: 'KeyVaultAnalytics(${law.name})'
    product: 'OMSGallery/KeyVaultAnalytics'
    promotionCode: ''
    publisher: 'Microsoft'
  }
}

resource kv_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: kv
  name: 'default'
  properties: {
    workspaceId: law.id
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

@description('The kv private dns zone required by Private Link support.')
resource pdzKv 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'

  // Enabling Azure Key Vault Private Link on the spoke vnet.
  resource vnetlnk 'virtualNetworkLinks' = {
    name: 'to_${targetVirtualNetwork.name}'
    location: 'global'
    properties: {
      virtualNetwork: {
        id: targetVirtualNetwork.id
      }
      registrationEnabled: false
    }
  }
}

@description('The network interface in the spoke vnet that enables connecting privately the aks regulated cluster with kv.')
resource peKv 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: 'pe-${kv.name}'
  location: location
  properties: {
    subnet: {
      id: targetVirtualNetwork::snetPrivatelinkendpoints.id
    }
    privateLinkServiceConnections: [
      {
        name: 'to-${targetVirtualNetwork.name}'
        properties: {
          privateLinkServiceId: kv.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }

  resource pdzg 'privateDnsZoneGroups' = {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'privatelink-akv-net'
          properties: {
            privateDnsZoneId: pdzKv.id
          }
        }
      ]
    }
  }
}

@description('The regional load balancer resource that ingests all the client requests and forward them back to the aks regulated cluster after passing the configured WAF rules.')
resource agw 'Microsoft.Network/applicationGateways@2022-01-01' = {
  name: 'agw-${clusterName}'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${miAppGateway.id}': {
      }
    }
  }
  zones: pickZones('Microsoft.Network', 'applicationGateways', location, 3)
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
    }
    sslPolicy: {
      policyType: 'Custom'
      cipherSuites: [
        'TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384'
        'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256'
      ]
      minProtocolVersion: 'TLSv1_2'
    }
    trustedRootCertificates: [
      {
        name: 'root-cert-wildcard-aks-ingress-contoso'
        properties: {
          keyVaultSecretId: kv::kvsAppGwIngressInternalAksIngressTls.properties.secretUri
        }
      }
    ]
    gatewayIPConfigurations: [
      {
        name: 'agw-ip-configuration'
        properties: {
          subnet: {
            id: targetVirtualNetwork::snetApplicationGateway.id
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'agw-frontend-ip-configuration'
        properties: {
          publicIPAddress: {
            id: resourceId(subscription().subscriptionId, targetResourceGroup.name, 'Microsoft.Network/publicIpAddresses', 'pip-BU0001A0005-00')
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'agw-frontend-ports'
        properties: {
          port: 443
        }
      }
    ]
    autoscaleConfiguration: {
      minCapacity: 0
      maxCapacity: 10
    }
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Prevention'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.2'
      disabledRuleGroups: []
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
    }
    enableHttp2: false
    sslCertificates: [
      {
        name: 'agw-${clusterName}-ssl-certificate'
        properties: {
          keyVaultSecretId:  kv::kvsGatewaySslCert.properties.secretUri
        }
      }
    ]
    probes: [
      {
        name: 'probe-bu0001a0005-00.aks-ingress.contoso.com'
        properties: {
          protocol: 'Https'
          path: '/favicon.ico'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
          minServers: 0
          match: {
          }
        }
      }
      {
        name: 'ingress-controller'
        properties: {
          protocol: 'Https'
          path: '/healthz'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
          minServers: 0
          match: {
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'bu0001a0005-00.aks-ingress.contoso.com'
        properties: {
          backendAddresses: [
            {
              ipAddress: '10.240.4.4'
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'aks-ingress-contoso-backendpool-httpsettings'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          hostName: 'bu0001a0005-00.aks-ingress.contoso.com'
          pickHostNameFromBackendAddress: false
          requestTimeout: 20
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', 'agw-${clusterName}','probe-bu0001a0005-00.aks-ingress.contoso.com')
          }
          trustedRootCertificates: [
            {
              id: resourceId('Microsoft.Network/applicationGateways/trustedRootCertificates', 'agw-${clusterName}','root-cert-wildcard-aks-ingress-contoso')
            }
          ]
        }
      }
    ]
    httpListeners: [
      {
        name: 'listener-https'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', 'agw-${clusterName}','agw-frontend-ip-configuration')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', 'agw-${clusterName}','agw-frontend-ports')
          }
          protocol: 'Https'
          sslCertificate: {
            id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', 'agw-${clusterName}','agw-${clusterName}-ssl-certificate')
          }
          hostName: 'bicycle.contoso.com'
          hostNames: []
          requireServerNameIndication: true
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'agw-routing-rules'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', 'agw-${clusterName}','listener-https')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', 'agw-${clusterName}','bu0001a0005-00.aks-ingress.contoso.com')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', 'agw-${clusterName}','aks-ingress-contoso-backendpool-httpsettings')
          }
        }
      }
    ]
  }
  dependsOn: [
    peKv
    kvMiAppGatewayKeyVaultReader_roleAssignment
    kvMiAppGatewaySecretsUserRole_roleAssignment
  ]
}

@description('The diagnostic settings configuration for the aks regulated cluster regional load balancer.')
resource agw_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: agw
  name: 'default'
  properties: {
    workspaceId: law.id
    logs: [
      {
        category: 'ApplicationGatewayAccessLog'
        enabled: true
      }
      {
        category: 'ApplicationGatewayPerformanceLog'
        enabled: true
      }
      {
        category: 'ApplicationGatewayFirewallLog'
        enabled: true
      }
    ]
  }
}

@description('The compute for operations jumpboxes; these machines are assigned to cluster operator users')
resource vmssJumpboxes 'Microsoft.Compute/virtualMachineScaleSets@2020-12-01' = {
  name: 'vmss-jumpboxes'
  location: location
  zones: pickZones('Microsoft.Compute', 'virtualMachineScaleSets', location, 3)
  sku: {
    name: 'Standard_DS1_v2'
    tier: 'Standard'
    capacity: 2
  }
  properties: {
    additionalCapabilities: {
      ultraSSDEnabled: false
    }
    overprovision: false
    singlePlacementGroup: true
    upgradePolicy: {
      mode: 'Automatic'
    }
    zoneBalance: false
    virtualMachineProfile: {
      diagnosticsProfile: {
        bootDiagnostics: {
          enabled: true
        }
      }
      osProfile: {
        computerNamePrefix: 'aksjmp'
        linuxConfiguration: {
          disablePasswordAuthentication: true
          provisionVMAgent: true
          ssh: {
            publicKeys: [
              {
                path: '/home/${jumpBoxDefaultAdminUserName}/.ssh/authorized_keys'
                keyData: 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCcFvQl2lYPcK1tMB3Tx2R9n8a7w5MJCSef14x0ePRFr9XISWfCVCNKRLM3Al/JSlIoOVKoMsdw5farEgXkPDK5F+SKLss7whg2tohnQNQwQdXit1ZjgOXkis/uft98Cv8jDWPbhwYj+VH/Aif9rx8abfjbvwVWBGeA/OnvfVvXnr1EQfdLJgMTTh+hX/FCXCqsRkQcD91MbMCxpqk8nP6jmsxJBeLrgfOxjH8RHEdSp4fF76YsRFHCi7QOwTE/6U+DpssgQ8MTWRFRat97uTfcgzKe5MOfuZHZ++5WFBgaTr1vhmSbXteGiK7dQXOk2cLxSvKkzeaiju9Jy6hoSl5oMygUVd5fNPQ94QcqTkMxZ9tQ9vPWOHwbdLRD31Ses3IBtDV+S6ehraiXf/L/e0jRUYk8IL/J543gvhOZ0hj2sQqTj9XS2hZkstZtrB2ywrJzV5ByETUU/oF9OsysyFgnaQdyduVqEPHaqXqnJvBngqqas91plyT3tSLMez3iT0s= unused-generated-by-azure'
              }
            ]
          }
        }
        customData: jumpBoxCloudInitAsBase64
        adminUsername: jumpBoxDefaultAdminUserName
      }
      storageProfile: {
        osDisk: {
          createOption: 'FromImage'
          caching: 'ReadOnly'
          diffDiskSettings: {
            option: 'Local'
          }
          osType: 'Linux'
        }
        imageReference: {
          id: jumpBoxImageResourceId
        }
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: 'vnet-spoke-BU0001A0005-01-nic01'
            properties: {
              primary: true
              enableIPForwarding: false
              enableAcceleratedNetworking: false
              networkSecurityGroup: null
              ipConfigurations: [
                {
                  name: 'default'
                  properties: {
                    primary: true
                    privateIPAddressVersion: 'IPv4'
                    publicIPAddressConfiguration: null
                    subnet: {
                      id: targetVirtualNetwork::snetManagmentOps.id
                    }
                  }
                }
              ]
            }
          }
        ]
      }
    }
  }
  dependsOn: [
    omsVmInsights
  ]

  resource extOmsAgentForLinux 'extensions' = {
    name: 'OMSExtension'
    properties: {
      publisher: 'Microsoft.EnterpriseCloud.Monitoring'
      type: 'OmsAgentForLinux'
      typeHandlerVersion: '1.13'
      autoUpgradeMinorVersion: true
      settings: {
        stopOnMultipleConnections: true
        azureResourceId: vmssJumpboxes.id
        workspaceId: reference(law.id, '2020-10-01').customerId
      }
      protectedSettings: {
        workspaceKey: listKeys(law.id, '2020-10-01').primarySharedKey
      }
    }
  }
}

resource alaAllAzureAdvisorAlert 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
  name: 'AllAzureAdvisorAlert'
  location: 'Global'
  properties: {
    scopes: [
      resourceGroup().id
    ]
    condition: {
      allOf: [
        {
          field: 'category'
          equals: 'Recommendation'
        }
        {
          field: 'operationName'
          equals: 'Microsoft.Advisor/recommendations/available/action'
        }
      ]
    }
    actions: {
      actionGroups: []
    }
    enabled: true
    description: 'All azure advisor alerts'
  }
}

/*** OUTPUTS ***/

output agwName string = agw.name
output keyVaultName string = kv.name
