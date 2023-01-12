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
param location string = 'eastus2'

@description('The Azure resource ID of a VM image that will be used for the jump box.')
@minLength(70)
param jumpBoxImageResourceId string

@description('A cloud init file (starting with #cloud-config) as a base 64 encoded string used to perform image customization on the jump box VMs. Used for user-management in this context.')
@minLength(100)
param jumpBoxCloudInitAsBase64 string

@description('Your cluster will be bootstrapped from this git repo.')
@minLength(9)
param gitOpsBootstrappingRepoHttpsUrl string

@description('Your cluster will be bootstrapped from this branch in the identified git repo.')
@minLength(1)
param gitOpsBootstrappingRepoBranch string = 'main'

/*** VARIABLES ***/

var kubernetesVersion = '1.25.2'

var subRgUniqueString = uniqueString('aks', subscription().subscriptionId, resourceGroup().id)
var clusterName = 'aks-${subRgUniqueString}'
var jumpBoxDefaultAdminUserName = uniqueString(clusterName, resourceGroup().id)
var acrName = 'acraks${subRgUniqueString}'
var kvName = 'kv-${clusterName}'

/*** EXISTING TENANT RESOURCES ***/

@description('Built-in \'Kubernetes cluster pod security restricted standards for Linux-based workloads\' Azure Policy for Kubernetes initiative definition')
var psdAKSLinuxRestrictiveId = tenantResourceId('Microsoft.Authorization/policySetDefinitions', '42b8ef37-b724-4e24-bbc8-7a7708edfe00')

@description('Built-in \'Kubernetes clusters should be accessible only over HTTPS\' Azure Policy for Kubernetes policy definition')
var pdEnforceHttpsIngressId = tenantResourceId('Microsoft.Authorization/policyDefinitions', '1a5b4dca-0b6f-4cf5-907c-56316bc1bf3d')

@description('Built-in \'Kubernetes clusters should use internal load balancers\' Azure Policy for Kubernetes policy definition')
var pdEnforceInternalLoadBalancersId = tenantResourceId('Microsoft.Authorization/policyDefinitions', '3fc4dc25-5baf-40d8-9b05-7fe74c1bc64e')

@description('Built-in \'Kubernetes cluster services should only use allowed external IPs\' Azure Policy for Kubernetes policy definition')
var pdAllowedExternalIPsId = tenantResourceId('Microsoft.Authorization/policyDefinitions', 'd46c275d-1680-448d-b2ec-e495a3b6cc89')

@description('Built-in \'[Deprecated]: Kubernetes cluster containers should only listen on allowed ports\' Azure Policy policy definition')
var pdApprovedContainerPortsOnly = tenantResourceId('Microsoft.Authorization/policyDefinitions', '440b515e-a580-421e-abeb-b159a61ddcbc')

@description('Built-in \'Kubernetes cluster services should listen only on allowed ports\' Azure Policy policy definition')
var pdApprovedServicePortsOnly = tenantResourceId('Microsoft.Authorization/policyDefinitions', '233a2a17-77ca-4fb1-9b6b-69223d272a44')

@description('Built-in \'Kubernetes cluster pods should use specified labels\' Azure Policy policy definition')
var pdMustUseSpecifiedLabels = tenantResourceId('Microsoft.Authorization/policyDefinitions', '46592696-4c7b-4bf3-9e45-6c2763bdc0a6')

@description('Built-in \'Kubernetes clusters should disable automounting API credentials\' Azure Policy policy definition')
var pdMustNotAutomountApiCreds = tenantResourceId('Microsoft.Authorization/policyDefinitions', '423dd1ba-798e-40e4-9c4d-b6902674b423')

@description('Built-in \'Kubernetes cluster containers should run with a read only root file systemv\' Azure Policy for Kubernetes policy definition')
var pdRoRootFilesystemId = tenantResourceId('Microsoft.Authorization/policyDefinitions', 'df49d893-a74c-421d-bc95-c663042e5b80')

@description('Built-in \'Kubernetes clusters should not use the default namespace\' Azure Policy for Kubernetes policy definition')
var pdDisallowNamespaceUsageId = tenantResourceId('Microsoft.Authorization/policyDefinitions', '9f061a12-e40d-4183-a00e-171812443373')

@description('Built-in \'AKS container CPU and memory resource limits should not exceed the specified limits\' Azure Policy for Kubernetes policy definition')
var pdEnforceResourceLimitsId = tenantResourceId('Microsoft.Authorization/policyDefinitions', 'e345eecc-fa47-480f-9e88-67dcc122b164')

@description('Built-in \'AKS containers should only use allowed images\' Azure Policy for Kubernetes policy definition')
var pdEnforceImageSourceId = tenantResourceId('Microsoft.Authorization/policyDefinitions', 'febd0533-8e55-448f-b837-bd0e06f16469')

/*** EXISTING RESOURCE GROUP RESOURCES ***/

@description('Spoke resource group')
resource spokeResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  scope: subscription()
  name: '${split(targetVnetResourceId, '/')[4]}'
}

@description('The Spoke virtual network')
resource vnetSpoke 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  scope: spokeResourceGroup
  name: '${last(split(targetVnetResourceId, '/'))}'

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

  // spoke virtual network's subnet for managment acr agent pools
  resource snetManagmentCrAgents 'subnets' existing = {
    name: 'snet-management-acragents'
  }

  // spoke virtual network's subnet for cluster system node pools
  resource snetClusterSystemNodePools 'subnets' existing = {
    name: 'snet-cluster-systemnodepool'
  }

  // spoke virtual network's subnet for cluster in-scope node pools
  resource snetClusterInScopeNodePools 'subnets' existing = {
    name: 'snet-cluster-inscopenodepools'
  }

  // spoke virtual network's subnet for cluster out-scope node pools
  resource snetClusterOutScopeNodePools 'subnets' existing = {
    name: 'snet-cluster-outofscopenodepools'
  }
}

resource pdzMc 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  scope: spokeResourceGroup
  name: 'privatelink.${location}.azmk8s.io'
}

@description('Used as primary entry point for workload. Expected to be assigned to an Azure Application Gateway.')
resource pipPrimaryCluster 'Microsoft.Network/publicIPAddresses@2022-05-01' existing = {
  scope: spokeResourceGroup
  name: 'pip-BU0001A0005-00'
}

@description('The in-cluster ingress controller identity used by the pod identity agent to acquire access tokens to read SSL certs from Azure Key Vault.')
resource miIngressController 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  scope: resourceGroup()
  name: 'mi-${clusterName}-ingresscontroller'
}

@description('Azure Container Registry.')
resource acr 'Microsoft.ContainerRegistry/registries@2022-02-01-preview' existing = {
  scope: resourceGroup()
  name: 'acraks${subRgUniqueString}'
}

@description('The secret storage management resource for the AKS regulated cluster.')
resource kv 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  scope: resourceGroup()
  name: kvName
  resource kvsAppGwIngressInternalAksIngressTls 'secrets' existing = {
    name: 'agw-ingress-internal-aks-ingress-contoso-com-tls'
  }
}

@description('Log Analytics Workspace.')
resource la 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' existing = {
  scope: resourceGroup()
  name: 'la-${clusterName}'
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

@description('Built-in Azure RBAC role that is applied to a Container Registry to grant with pull privileges. Granted to AKS kubelet cluster\'s identity.')
resource containerRegistryPullRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
  scope: subscription()
}

@description('Built-in Azure RBAC role that is applied to a Subscription to grant with publishing metrics. Granted to in-cluster agent\'s identity.')
resource monitoringMetricsPublisherRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '3913510d-42f4-4e42-8a64-420c390055eb'
  scope: subscription()
}

/*** RESOURCES ***/

@description('The control plane identity used by the cluster. Used for networking access (VNET joining and DNS updating)')
resource miClusterControlPlane 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: 'mi-${clusterName}-controlplane'
  location: location
}

@description('The regional load balancer identity used by your Application Gateway instance to acquire access tokens to read certs and secrets from Azure Key Vault.')
resource miAppGateway 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: 'mi-appgateway'
  location: location
}

@description('Grant the cluster control plane managed identity with managed identity operator role permissions; this allows to assign compute with the ingress controller managed identity; this is required for Azure Pod Identity.')
resource icMiClusterControlPlaneManagedIdentityOperatorRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: miIngressController
  name: guid(resourceGroup().id, miClusterControlPlane.name, managedIdentityOperatorRole.id)
  properties: {
    roleDefinitionId: managedIdentityOperatorRole.id
    principalId: miClusterControlPlane.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource kvsGatewaySslCert 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: kv
  name: 'sslcert'
  properties: {
    value: appGatewayListenerCertificate
  }
  dependsOn: [
    miAppGateway
  ]
}

@description('Grant the Azure Application Gateway managed identity with Key Vault secrets user role permissions; this allows pulling secrets from Key Vault.')
resource kvMiAppGatewaySecretsUserRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: kv
  name: guid(resourceGroup().id, miAppGateway.name, keyVaultSecretsUserRole.id)
  properties: {
    roleDefinitionId: keyVaultSecretsUserRole.id
    principalId: miAppGateway.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

@description('Grant the Azure Application Gateway managed identity with Key Vault reader role permissions; this allows pulling frontend and backend certificates.')
resource kvMiAppGatewayKeyVaultReader_roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: kv
  name: guid(resourceGroup().id, miAppGateway.name, keyVaultReaderRole.id)
  properties: {
    roleDefinitionId: keyVaultReaderRole.id
    principalId: miAppGateway.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource lawAllPrometheus 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = {
  parent: la
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
  parent: la
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
  parent: la
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
  name: 'ContainerInsights(${la.name})'
  location: location
  properties: {
    workspaceResourceId: la.id
  }
  plan: {
    name: 'ContainerInsights(${la.name})'
    product: 'OMSGallery/ContainerInsights'
    promotionCode: ''
    publisher: 'Microsoft'
  }
}

resource omsVmInsights 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'VMInsights(${la.name})'
  location: location
  properties: {
    workspaceResourceId: la.id
  }
  plan: {
    name: 'VMInsights(${la.name})'
    product: 'OMSGallery/VMInsights'
    promotionCode: ''
    publisher: 'Microsoft'
  }
}

resource omsSecurityInsights 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'SecurityInsights(${la.name})'
  location: location
  properties: {
    workspaceResourceId: la.id
  }
  plan: {
    name: 'SecurityInsights(${la.name})'
    product: 'OMSGallery/SecurityInsights'
    promotionCode: ''
    publisher: 'Microsoft'
  }
}

resource miwSecurityInsights 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid(omsSecurityInsights.name)
  location: location
  tags: {
    'hidden-title': 'Azure Kubernetes Service (AKS) Security - ${la.name}'
  }
  kind: 'shared'
  properties: {
    displayName: 'Azure Kubernetes Service (AKS) Security - ${la.name}'
    serializedData: '{"version":"Notebook/1.0","items":[{"type":1,"content":{"json":"## AKS Security\\n"},"name":"text - 2"},{"type":9,"content":{"version":"KqlParameterItem/1.0","crossComponentResources":["{workspaces}"],"parameters":[{"id":"311d3728-7f8a-4b16-8a34-097d099323d5","version":"KqlParameterItem/1.0","name":"subscription","label":"Subscription","type":6,"isRequired":true,"multiSelect":true,"quote":"\'","delimiter":",","value":[],"typeSettings":{"additionalResourceOptions":[],"includeAll":false,"showDefault":false}},{"id":"3a56d260-4fb9-46d6-b121-cea854104c91","version":"KqlParameterItem/1.0","name":"workspaces","label":"Workspaces","type":5,"isRequired":true,"multiSelect":true,"quote":"\'","delimiter":",","query":"where type =~ \'microsoft.operationalinsights/workspaces\'\\r\\n| where strcat(\'/subscriptions/\',subscriptionId) in ({subscription})\\r\\n| project id","crossComponentResources":["{subscription}"],"typeSettings":{"additionalResourceOptions":["value::all"]},"queryType":1,"resourceType":"microsoft.resourcegraph/resources","value":["value::all"]},{"id":"9615cea6-c661-470a-b4ae-1aab8ae6f448","version":"KqlParameterItem/1.0","name":"clustername","label":"Cluster name","type":5,"isRequired":true,"multiSelect":true,"quote":"\'","delimiter":",","query":"where type == \\"microsoft.containerservice/managedclusters\\"\\r\\n| where strcat(\'/subscriptions/\',subscriptionId) in ({subscription})\\r\\n| distinct tolower(id)","crossComponentResources":["{subscription}"],"value":["value::all"],"typeSettings":{"resourceTypeFilter":{"microsoft.containerservice/managedclusters":true},"additionalResourceOptions":["value::all"],"showDefault":false},"timeContext":{"durationMs":86400000},"queryType":1,"resourceType":"microsoft.resourcegraph/resources"},{"id":"236c00ec-1493-4e60-927a-a18b8b120cd5","version":"KqlParameterItem/1.0","name":"timeframe","label":"Time range","type":4,"description":"Time","isRequired":true,"value":{"durationMs":172800000},"typeSettings":{"selectableValues":[{"durationMs":300000},{"durationMs":900000},{"durationMs":1800000},{"durationMs":3600000},{"durationMs":14400000},{"durationMs":43200000},{"durationMs":86400000},{"durationMs":172800000},{"durationMs":259200000},{"durationMs":604800000},{"durationMs":1209600000},{"durationMs":2419200000},{"durationMs":2592000000},{"durationMs":5184000000},{"durationMs":7776000000}],"allowCustom":true},"timeContext":{"durationMs":86400000}},{"id":"bf0a3e4f-fff9-450c-b9d3-c8c1dded9787","version":"KqlParameterItem/1.0","name":"nodeRgDetails","type":1,"query":"where type == \\"microsoft.containerservice/managedclusters\\"\\r\\n| where tolower(id) in ({clustername})\\r\\n| project nodeRG = properties.nodeResourceGroup, subscriptionId, id = toupper(id)\\r\\n| project nodeRgDetails = strcat(\'\\"\', nodeRG, \\";\\", subscriptionId, \\";\\", id, \'\\"\')","crossComponentResources":["value::all"],"isHiddenWhenLocked":true,"timeContext":{"durationMs":86400000},"queryType":1,"resourceType":"microsoft.resourcegraph/resources"},{"id":"df53126c-c40f-43d5-b99f-97ee3785c086","version":"KqlParameterItem/1.0","name":"diagnosticClusters","type":1,"query":"union withsource=_TableName *\\r\\n| where _TableName == \\"AzureDiagnostics\\" and Category == \\"kube-audit\\"\\r\\n| summarize diagnosticClusters = dcount(ResourceId)\\r\\n| project isDiagnosticCluster = iff(diagnosticClusters > 0, \\"yes\\", \\"no\\")","crossComponentResources":["{workspaces}"],"isHiddenWhenLocked":true,"timeContext":{"durationMs":172800000},"timeContextFromParameter":"timeframe","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces"}],"style":"pills","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces"},"name":"parameters - 3"},{"type":11,"content":{"version":"LinkItem/1.0","style":"tabs","links":[{"id":"07cf87dc-8234-47db-850d-ec41b2687b2a","cellValue":"mainTab","linkTarget":"parameter","linkLabel":"Microsoft Defender for Kubernetes","subTarget":"alerts","preText":"","style":"link"},{"id":"44033ee6-d83e-4253-a732-c258ef1da545","cellValue":"mainTab","linkTarget":"parameter","linkLabel":"Analytics over Diagnostic logs","subTarget":"diagnostics","style":"link"}]},"name":"links - 22"},{"type":12,"content":{"version":"NotebookGroup/1.0","groupType":"editable","items":[{"type":1,"content":{"json":"## Microsoft Defender for AKS coverage"},"name":"text - 10"},{"type":3,"content":{"version":"KqlItem/1.0","query":"datatable (Event:string)\\r\\n    [\\"AKS Workbook\\"]\\r\\n| extend cluster = (strcat(\\"[\\", \\"{clustername}\\", \\"]\\"))\\r\\n| extend cluster = todynamic(replace(\\"\'\\", \'\\"\', cluster))\\r\\n| mvexpand cluster\\r\\n| extend subscriptionId = extract(@\\"/subscriptions/([^/]+)\\", 1, tostring(cluster))\\r\\n| summarize AksClusters = count() by subscriptionId, DefenderForAks = 0\\r\\n| union\\r\\n(\\r\\nsecurityresources\\r\\n| where type =~ \\"microsoft.security/pricings\\"\\r\\n| where name == \\"KubernetesService\\"\\r\\n| project DefenderForAks = iif(properties.pricingTier == \'Standard\', 1, 0), AksClusters = 0, subscriptionId\\r\\n)\\r\\n| summarize AksClusters = sum(AksClusters), DefenderForAks = sum(DefenderForAks) by subscriptionId\\r\\n| project Subscription = strcat(\'/subscriptions/\', subscriptionId), [\\"AKS clusters\\"] = AksClusters, [\'Defender for AKS\'] = iif(DefenderForAks > 0,\'yes\',\'no\'), [\'Onboard Microsoft Defender\'] = iif(DefenderForAks > 0, \'\', \'https://ms.portal.azure.com/#blade/Microsoft_Azure_Security/SecurityMenuBlade/26\')\\r\\n| order by [\'Defender for AKS\'] asc","size":0,"queryType":1,"resourceType":"microsoft.resourcegraph/resources","crossComponentResources":["{subscription}"],"gridSettings":{"formatters":[{"columnMatch":"Defender for AKS","formatter":18,"formatOptions":{"thresholdsOptions":"icons","thresholdsGrid":[{"operator":"==","thresholdValue":"no","representation":"4","text":""},{"operator":"Default","thresholdValue":null,"representation":"success","text":""}]}},{"columnMatch":"Onboard Microsoft Defender","formatter":7,"formatOptions":{"linkTarget":"Url","linkLabel":""}}]}},"customWidth":"66","name":"query - 9"},{"type":3,"content":{"version":"KqlItem/1.0","query":"datatable (Event:string)\\r\\n    [\\"AKS Workbook\\"]\\r\\n| extend cluster = (strcat(\\"[\\", \\"{clustername}\\", \\"]\\"))\\r\\n| extend cluster = todynamic(replace(\\"\'\\", \'\\"\', cluster))\\r\\n| mvexpand cluster\\r\\n| extend subscriptionId = extract(@\\"/subscriptions/([^/]+)\\", 1, tostring(cluster))\\r\\n| summarize AksClusters = count() by subscriptionId, DefenderForAks = 0\\r\\n| union\\r\\n(\\r\\nsecurityresources\\r\\n| where type =~ \\"microsoft.security/pricings\\"\\r\\n| where name == \\"KubernetesService\\"\\r\\n| project DefenderForAks = iif(properties.pricingTier == \'Standard\', 1, 0), AksClusters = 0, subscriptionId\\r\\n)\\r\\n| summarize AksClusters = sum(AksClusters), DefenderForAks = sum(DefenderForAks) by subscriptionId\\r\\n| project Subscription = 1, [\'Defender for AKS\'] = iif(DefenderForAks > 0,\'Protected by Microsoft Defender\',\'Not protected by Microsoft Defender\')","size":0,"queryType":1,"resourceType":"microsoft.resourcegraph/resources","crossComponentResources":["{subscription}"],"visualization":"piechart"},"customWidth":"33","name":"query - 11"},{"type":1,"content":{"json":"### AKS alerts overview"},"name":"text - 21"},{"type":3,"content":{"version":"KqlItem/1.0","query":"SecurityAlert \\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where TimeGenerated {timeframe}\\r\\n| where AlertType startswith \\"AKS_\\"\\r\\n| project image = tostring(todynamic(ExtendedProperties)[\\"Container image\\"]), AlertType\\r\\n| where image != \\"\\"\\r\\n| summarize AlertTypes = dcount(AlertType) by image\\r\\n| where AlertTypes > 1\\r\\n//| render piechart \\r\\n","size":4,"title":"Images with multiple alerts","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"visualization":"tiles","tileSettings":{"showBorder":false,"titleContent":{"columnMatch":"image","formatter":1},"leftContent":{"columnMatch":"AlertTypes","formatter":12,"formatOptions":{"palette":"auto"},"numberFormat":{"unit":17,"options":{"maximumSignificantDigits":3,"maximumFractionDigits":2}}}}},"customWidth":"33","name":"query - 12"},{"type":3,"content":{"version":"KqlItem/1.0","query":"SecurityAlert \\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where TimeGenerated {timeframe}\\r\\n| where AlertType startswith \\"AKS_\\"\\r\\n| project AlertType, name = extract(@\\"/MICROSOFT.CONTAINERSERVICE/MANAGEDCLUSTERS/(.+)\\", 1, ResourceId)\\r\\n| summarize AlertTypes = dcount(AlertType)  by  name\\r\\n| where AlertTypes > 1\\r\\n","size":4,"title":"Clusters with multiple alert types","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"visualization":"tiles","tileSettings":{"showBorder":false,"titleContent":{"columnMatch":"name","formatter":1},"leftContent":{"columnMatch":"AlertTypes","formatter":12,"formatOptions":{"palette":"auto"},"numberFormat":{"unit":17,"options":{"maximumSignificantDigits":3,"maximumFractionDigits":2}}}}},"customWidth":"33","name":"query - 12 - Copy"},{"type":3,"content":{"version":"KqlItem/1.0","query":"SecurityAlert \\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where TimeGenerated {timeframe}\\r\\n| where AlertType startswith \\"AKS_\\"\\r\\n| project AlertType, name = extract(@\\"/MICROSOFT.CONTAINERSERVICE/MANAGEDCLUSTERS/(.+)\\", 1, ResourceId)\\r\\n| summarize count() by name\\r\\n\\r\\n","size":4,"title":"Alerts triggered by cluster","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"visualization":"tiles","tileSettings":{"showBorder":false,"titleContent":{"columnMatch":"name","formatter":1},"leftContent":{"columnMatch":"count_","formatter":12,"formatOptions":{"palette":"auto"},"numberFormat":{"unit":17,"options":{"maximumSignificantDigits":3,"maximumFractionDigits":2}}}}},"customWidth":"33","name":"query - 12 - Copy - Copy"},{"type":1,"content":{"json":"### Seucirty alerts details\\r\\n\\r\\nTo filter, press on the severities below.\\r\\nYou can also filter based on a specific resource."},"name":"text - 18"},{"type":3,"content":{"version":"KqlItem/1.0","query":"SecurityAlert\\r\\n| where TimeGenerated {timeframe}\\r\\n| extend rg = extract(@\\"/resourcegroups/([^/]+)\\", 1, tolower(ResourceId))\\r\\n| extend sub = extract(@\\"/subscriptions/([^/]+)\\", 1, tolower(ResourceId))\\r\\n| extend nodesDetailsArr = todynamic(\'{nodeRgDetails}\')\\r\\n| mv-expand singleNodeDetails = nodesDetailsArr\\r\\n| extend singleNodeArr = split(singleNodeDetails, \\";\\")\\r\\n| where tolower(singleNodeArr[0]) == rg and tolower(singleNodeArr[1]) == sub\\r\\n| project AlertSeverity\\r\\n| union\\r\\n(\\r\\nSecurityAlert \\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where TimeGenerated {timeframe}\\r\\n| where AlertType startswith \\"AKS_\\"\\r\\n| project AlertSeverity\\r\\n)\\r\\n| summarize count() by AlertSeverity","size":0,"title":"Alerts by severity","exportMultipleValues":true,"exportedParameters":[{"fieldName":"AlertSeverity","parameterName":"severity","parameterType":1,"quote":""}],"queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"visualization":"tiles","tileSettings":{"showBorder":false,"titleContent":{"columnMatch":"AlertSeverity","formatter":1},"leftContent":{"columnMatch":"count_","formatter":12,"formatOptions":{"palette":"auto"},"numberFormat":{"unit":17,"options":{"maximumSignificantDigits":3,"maximumFractionDigits":2}}}}},"customWidth":"11","name":"Alerts by severity"},{"type":3,"content":{"version":"KqlItem/1.0","query":"SecurityAlert\\r\\n| where TimeGenerated {timeframe}\\r\\n| where \\"{severity}\\" has AlertSeverity or isempty(\\"{severity}\\")\\r\\n| extend rg = extract(@\\"/resourcegroups/([^/]+)\\", 1, tolower(ResourceId))\\r\\n| extend sub = extract(@\\"/subscriptions/([^/]+)\\", 1, tolower(ResourceId))\\r\\n| extend nodesDetailsArr = todynamic(\'{nodeRgDetails}\')\\r\\n| mv-expand singleNodeDetails = nodesDetailsArr\\r\\n| extend singleNodeArr = split(singleNodeDetails, \\";\\")\\r\\n| where tolower(singleNodeArr[0]) == rg and tolower(singleNodeArr[1]) == sub\\r\\n| project ResourceId\\r\\n| union\\r\\n(\\r\\nSecurityAlert \\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where \\"{severity}\\" has AlertSeverity or isempty(\\"{severity}\\")\\r\\n| where TimeGenerated {timeframe}\\r\\n| where AlertType startswith \\"AKS_\\"\\r\\n| project ResourceId\\r\\n)\\r\\n| summarize Alerts = count() by ResourceId\\r\\n| order by Alerts desc\\r\\n| limit 10","size":0,"title":"Resources with most alerts","exportFieldName":"ResourceId","exportParameterName":"selectedResource","exportDefaultValue":"not_selected","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"gridSettings":{"formatters":[{"columnMatch":"Alerts","formatter":4,"formatOptions":{"palette":"red"}}]}},"customWidth":"22","name":"Resources with most alerts"},{"type":3,"content":{"version":"KqlItem/1.0","query":"\\r\\nSecurityAlert\\r\\n| where TimeGenerated {timeframe}\\r\\n| where \\"{severity}\\" has AlertSeverity or isempty(\\"{severity}\\")\\r\\n| extend rg = extract(@\\"/resourcegroups/([^/]+)\\", 1, tolower(ResourceId))\\r\\n| extend sub = extract(@\\"/subscriptions/([^/]+)\\", 1, tolower(ResourceId))\\r\\n| extend nodesDetailsArr = todynamic(\'{nodeRgDetails}\')\\r\\n| mv-expand singleNodeDetails = nodesDetailsArr\\r\\n| extend singleNodeArr = split(singleNodeDetails, \\";\\")\\r\\n| where tolower(singleNodeArr[0]) == rg and tolower(singleNodeArr[1]) == sub\\r\\n| extend AlertResourceType = \\"VM alerts\\"\\r\\n| union\\r\\n(\\r\\nSecurityAlert \\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where \\"{severity}\\" has AlertSeverity or isempty(\\"{severity}\\")\\r\\n| where TimeGenerated {timeframe}\\r\\n| where AlertType startswith \\"AKS_\\"\\r\\n| extend AlertResourceType = \\"Cluster alerts\\"\\r\\n)\\r\\n| summarize Alerts = count() by bin(TimeGenerated, {timeframe:grain}), AlertResourceType","size":0,"title":"Alerts over time","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"visualization":"timechart"},"customWidth":"66","name":"Alerts over time"},{"type":3,"content":{"version":"KqlItem/1.0","query":"SecurityAlert\\r\\n| where TimeGenerated {timeframe}\\r\\n| where \\"{severity}\\" has AlertSeverity or isempty(\\"{severity}\\")\\r\\n| extend rg = extract(@\\"/resourcegroups/([^/]+)\\", 1, tolower(ResourceId))\\r\\n| extend sub = extract(@\\"/subscriptions/([^/]+)\\", 1, tolower(ResourceId))\\r\\n| extend nodesDetailsArr = todynamic(\'{nodeRgDetails}\')\\r\\n| mv-expand singleNodeDetails = nodesDetailsArr\\r\\n| extend singleNodeArr = split(singleNodeDetails, \\";\\")\\r\\n| where tolower(singleNodeArr[0]) == rg and tolower(singleNodeArr[1]) == sub\\r\\n| where tolower(ResourceId) == tolower(\\"{selectedResource}\\") or \\"{selectedResource}\\" == \\"not_selected\\"\\r\\n| project [\\"Resource name\\"] = ResourceId, TimeGenerated, AlertSeverity, [\\"AKS cluster\\"] = toupper(singleNodeArr[2]), DisplayName, AlertLink\\r\\n| union\\r\\n(\\r\\nSecurityAlert\\r\\n| where TimeGenerated {timeframe}\\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where \\"{severity}\\" has AlertSeverity or isempty(\\"{severity}\\")\\r\\n| where AlertType startswith \\"AKS_\\"\\r\\n| where tolower(ResourceId) == tolower(\\"{selectedResource}\\") or \\"{selectedResource}\\" == \\"not_selected\\"\\r\\n| project [\\"Resource name\\"] = ResourceId, TimeGenerated, AlertSeverity, [\\"AKS cluster\\"] = ResourceId, DisplayName, AlertLink\\r\\n)\\r\\n| order by TimeGenerated asc","size":0,"title":"Microsoft Defender alerts","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"gridSettings":{"formatters":[{"columnMatch":"AlertLink","formatter":7,"formatOptions":{"linkTarget":"Url","linkLabel":"Go to alert "}}],"filter":true},"sortBy":[]},"name":"Microsoft Defender alerts","styleSettings":{"showBorder":true}}]},"conditionalVisibility":{"parameterName":"mainTab","comparison":"isEqualTo","value":"alerts"},"name":"Defender Alerts"},{"type":12,"content":{"version":"NotebookGroup/1.0","groupType":"editable","items":[{"type":1,"content":{"json":"## Diagnostic logs coverage"},"name":"text - 15"},{"type":3,"content":{"version":"KqlItem/1.0","query":"union withsource=_TableName *\\r\\n| where _TableName == \\"AzureDiagnostics\\" and Category == \\"kube-audit\\"\\r\\n| summarize count() by ResourceId = tolower(ResourceId)\\r\\n| summarize logsClusters = make_set(ResourceId)\\r\\n| extend selectedClusters = \\"[{clustername}]\\"\\r\\n| extend selectedClusters = replace(\\"\'\\", \'\\"\', selectedClusters)\\r\\n| extend selectedClusters = todynamic(selectedClusters)\\r\\n| mv-expand clusterId = selectedClusters\\r\\n| project clusterId = toupper(tostring(clusterId)), [\\"Diagnostic logs\\"] = (logsClusters has tostring(clusterId))\\r\\n| extend [\\"Diagnostic settings\\"] = iff([\\"Diagnostic logs\\"] == false, strcat(\\"https://ms.portal.azure.com/#@microsoft.onmicrosoft.com/resource\\", clusterId, \\"/diagnostics\\"), \\"\\")\\r\\n","size":0,"timeContext":{"durationMs":172800000},"timeContextFromParameter":"timeframe","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"gridSettings":{"formatters":[{"columnMatch":"Diagnostic logs","formatter":18,"formatOptions":{"thresholdsOptions":"icons","thresholdsGrid":[{"operator":"==","thresholdValue":"false","representation":"critical","text":""},{"operator":"Default","thresholdValue":null,"representation":"success","text":""}]}},{"columnMatch":"Diagnostic settings","formatter":7,"formatOptions":{"linkTarget":"Url"}}],"filter":true,"sortBy":[{"itemKey":"$gen_thresholds_Diagnostic logs_1","sortOrder":2}]},"sortBy":[{"itemKey":"$gen_thresholds_Diagnostic logs_1","sortOrder":2}]},"customWidth":"66","name":"query - 14"},{"type":3,"content":{"version":"KqlItem/1.0","query":"union withsource=_TableName *\\r\\n| where _TableName == \\"AzureDiagnostics\\" and Category == \\"kube-audit\\"\\r\\n| summarize count() by ResourceId = tolower(ResourceId)\\r\\n| summarize logsClusters = make_set(ResourceId)\\r\\n| extend selectedClusters = \\"[{clustername}]\\"\\r\\n| extend selectedClusters = replace(\\"\'\\", \'\\"\', selectedClusters)\\r\\n| extend selectedClusters = todynamic(selectedClusters)\\r\\n| mv-expand clusterId = selectedClusters\\r\\n| project clusterId = toupper(tostring(clusterId)), hasDiagnosticLogs = (logsClusters has tostring(clusterId))\\r\\n| summarize [\\"number of clusters\\"] = count() by hasDiagnosticLogs\\r\\n| extend hasDiagnosticLogs = iff(hasDiagnosticLogs == true, \\"Clusters with Diagnostic logs\\", \\"Clusters without Diagnostic logs\\")\\r\\n","size":0,"timeContext":{"durationMs":172800000},"timeContextFromParameter":"timeframe","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"visualization":"piechart"},"customWidth":"33","name":"query - 17"},{"type":12,"content":{"version":"NotebookGroup/1.0","groupType":"editable","items":[{"type":1,"content":{"json":"## Cluster operations"},"name":"text - 16"},{"type":11,"content":{"version":"LinkItem/1.0","style":"tabs","links":[{"id":"3f616701-fd4b-482c-aff1-a85414daa05c","cellValue":"dispalyedGraph","linkTarget":"parameter","linkLabel":"Masterclient operations","subTarget":"masterclient","preText":"","style":"link"},{"id":"e6fa55f1-7d57-4f5e-8e83-429740853731","cellValue":"dispalyedGraph","linkTarget":"parameter","linkLabel":"Pod creation operations","subTarget":"podCreation","style":"link"},{"id":"f4c46251-0090-4ca3-a81c-0686bff3ff35","cellValue":"dispalyedGraph","linkTarget":"parameter","linkLabel":"Secret get\\\\list operations","subTarget":"secretOperation","style":"link"}]},"name":"links - 11"},{"type":3,"content":{"version":"KqlItem/1.0","query":"AzureDiagnostics \\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where TimeGenerated {timeframe}\\r\\n| where Category == \\"kube-audit\\"\\r\\n| where log_s has \\"masterclient\\"\\r\\n| project TimeGenerated, parse_json(log_s), ResourceId\\r\\n| project TimeGenerated, ResourceId, username = tostring(log_s[\\"user\\"].username)\\r\\n| where username == \\"masterclient\\"\\r\\n| extend name = extract(@\\"/MICROSOFT.CONTAINERSERVICE/MANAGEDCLUSTERS/(.+)\\", 1, ResourceId)\\r\\n| summarize count() by name, bin(TimeGenerated, 1h)","size":0,"queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"visualization":"timechart","tileSettings":{"showBorder":false,"titleContent":{"columnMatch":"name","formatter":1},"leftContent":{"columnMatch":"count_","formatter":12,"formatOptions":{"palette":"auto"},"numberFormat":{"unit":17,"options":{"maximumSignificantDigits":3,"maximumFractionDigits":2}}}},"chartSettings":{"yAxis":["count_"]}},"conditionalVisibility":{"parameterName":"dispalyedGraph","comparison":"isEqualTo","value":"masterclient"},"name":"Masterclient operations","styleSettings":{"showBorder":true}},{"type":3,"content":{"version":"KqlItem/1.0","query":"AzureDiagnostics\\r\\n| where Category == \\"kube-audit\\"\\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where TimeGenerated {timeframe}\\r\\n| where log_s has \\"pods\\"\\r\\n| project TimeGenerated, parse_json(log_s), ResourceId\\r\\n| project AzureResourceId = ResourceId, TimeGenerated,\\r\\n RequestURI = tostring(log_s[\\"requestURI\\"]),\\r\\n Verb = tostring(log_s[\\"verb\\"]),\\r\\n ObjectRef = log_s[\\"objectRef\\"],\\r\\n ResponseStatus = log_s[\\"responseStatus\\"]\\r\\n//Main query\\r\\n| where ObjectRef.resource == \\"pods\\" and Verb == \\"create\\" and ResponseStatus.code startswith \\"20\\"\\r\\n  and RequestURI endswith \\"/pods\\"\\r\\n| extend name = extract(@\\"/MICROSOFT.CONTAINERSERVICE/MANAGEDCLUSTERS/(.+)\\", 1, AzureResourceId)\\r\\n| summarize count() by name, bin(TimeGenerated, 1h)","size":0,"queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"visualization":"timechart"},"conditionalVisibility":{"parameterName":"dispalyedGraph","comparison":"isEqualTo","value":"podCreation"},"name":"pods creation","styleSettings":{"showBorder":true}},{"type":3,"content":{"version":"KqlItem/1.0","query":"AzureDiagnostics\\r\\n| where Category == \\"kube-audit\\"\\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where TimeGenerated {timeframe}\\r\\n| where log_s has \\"secrets\\"\\r\\n| project TimeGenerated, parse_json(log_s), ResourceId\\r\\n| project AzureResourceId = ResourceId, TimeGenerated,\\r\\n RequestURI = tostring(log_s[\\"requestURI\\"]),\\r\\n Verb = tostring(log_s[\\"verb\\"]),\\r\\n ObjectRef = log_s[\\"objectRef\\"],\\r\\n ResponseStatus = log_s[\\"responseStatus\\"]\\r\\n//Main query\\r\\n| where ObjectRef.resource == \\"secrets\\" and (Verb == \\"list\\" or Verb == \\"get\\") and ResponseStatus.code startswith \\"20\\"\\r\\n| where ObjectRef.name != \\"tunnelfront\\" and ObjectRef.name != \\"tunnelend\\" and ObjectRef.name != \\"kubernetes-dashboard-key-holder\\"\\r\\n| extend name = extract(@\\"/MICROSOFT.CONTAINERSERVICE/MANAGEDCLUSTERS/(.+)\\", 1, AzureResourceId)\\r\\n| summarize count() by name, bin(TimeGenerated, 1h)","size":0,"timeContext":{"durationMs":172800000},"timeContextFromParameter":"timeframe","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"visualization":"timechart","gridSettings":{"sortBy":[{"itemKey":"count_","sortOrder":2}]},"sortBy":[{"itemKey":"count_","sortOrder":2}]},"conditionalVisibility":{"parameterName":"dispalyedGraph","comparison":"isEqualTo","value":"secretOperation"},"name":"secrets operation","styleSettings":{"showBorder":true}},{"type":3,"content":{"version":"KqlItem/1.0","query":"let ascAlerts = \\nunion withsource=_TableName *\\n| where _TableName == \\"SecurityAlert\\"\\n| where tolower(ResourceId) in ({clustername})\\n| where TimeGenerated {timeframe}\\n| extend AlertType = column_ifexists(\\"AlertType\\", \\"\\")\\n| where AlertType == \\"AKS_PrivilegedContainer\\"\\n| extend ExtendedProperties = column_ifexists(\\"ExtendedProperties\\", todynamic(\\"\\"))\\n| extend ExtendedProperties = parse_json(ExtendedProperties)\\n| extend AlertLink = column_ifexists(\\"AlertLink\\", \\"\\")\\n| summarize arg_min(TimeGenerated, AlertLink) by AzureResourceId = ResourceId, name = tostring(ExtendedProperties[\\"Pod name\\"]), podNamespace =  tostring(ExtendedProperties[\\"Namespace\\"])\\n;\\nlet podOperations = AzureDiagnostics\\n| where Category == \\"kube-audit\\"\\n| where tolower(ResourceId) in ({clustername})\\n| where TimeGenerated {timeframe}\\n| where log_s has \\"privileged\\"\\n| project TimeGenerated, parse_json(log_s), ResourceId\\n| project AzureResourceId = ResourceId, TimeGenerated,\\n RequestURI = tostring(log_s[\\"requestURI\\"]),\\n Verb = tostring(log_s[\\"verb\\"]),\\n ObjectRef = log_s[\\"objectRef\\"],\\n RequestObject = log_s[\\"requestObject\\"],\\n ResponseStatus = log_s[\\"responseStatus\\"],\\n ResponseObject = log_s[\\"responseObject\\"]\\n//Main query\\n| where ObjectRef.resource == \\"pods\\" and Verb == \\"create\\" and ResponseStatus.code startswith \\"20\\" and RequestObject has \\"privileged\\"\\n  and RequestURI endswith \\"/pods\\"\\n| extend containers = RequestObject.spec.containers\\n| mvexpand containers\\n| where containers.securityContext.privileged == true\\n| summarize TimeGenerated = min(TimeGenerated) by\\n            name = tostring(ResponseObject.metadata.name),\\n            podNamespace = tostring(ResponseObject.metadata.namespace),\\n            imageName = tostring(containers.image),\\n            containerName = tostring(containers.name),\\n            AzureResourceId\\n| extend id = strcat(name,\\";\\", AzureResourceId)\\n| extend parent = AzureResourceId\\n| join kind=leftouter (ascAlerts) on AzureResourceId, name, podNamespace\\n;\\nlet cached = materialize(podOperations)\\n;\\nlet clusters = cached | distinct AzureResourceId\\n;\\n// Main query\\ncached\\n| union\\n(\\nclusters\\n| project \\n            name = AzureResourceId,\\n            id = AzureResourceId,\\n            parent = \\"\\"      \\n)\\n| project-away name1, podNamespace1, TimeGenerated1","size":1,"title":"Privileged containers creation","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"visualization":"table","gridSettings":{"formatters":[{"columnMatch":"name","formatter":13,"formatOptions":{"linkTarget":null,"showIcon":true}},{"columnMatch":"AzureResourceId","formatter":5},{"columnMatch":"id","formatter":5},{"columnMatch":"parent","formatter":5},{"columnMatch":"AlertLink","formatter":7,"formatOptions":{"linkTarget":"Url","linkLabel":""}}],"hierarchySettings":{"idColumn":"id","parentColumn":"parent","treeType":0,"expanderColumn":"name"}},"sortBy":[]},"customWidth":"66","name":"Privileged container","styleSettings":{"showBorder":true}},{"type":3,"content":{"version":"KqlItem/1.0","query":"SecurityAlert \\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where TimeGenerated {timeframe}\\r\\n| where AlertType == \\"AKS_PrivilegedContainer\\"\\r\\n| project name = extract(@\\"/MICROSOFT.CONTAINERSERVICE/MANAGEDCLUSTERS/(.+)\\", 1, ResourceId)\\r\\n| summarize alert = count() by name","size":1,"title":"AKS clusters with related Microsoft Defender alerts","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"visualization":"piechart","tileSettings":{"showBorder":false,"titleContent":{"columnMatch":"name","formatter":1},"leftContent":{"columnMatch":"alert","formatter":12,"formatOptions":{"palette":"auto"},"numberFormat":{"unit":17,"options":{"maximumSignificantDigits":3,"maximumFractionDigits":2}}}},"graphSettings":{"type":0,"topContent":{"columnMatch":"name","formatter":1},"centerContent":{"columnMatch":"alert","formatter":1,"numberFormat":{"unit":17,"options":{"maximumSignificantDigits":3,"maximumFractionDigits":2}}}}},"customWidth":"33","name":"query - 7","styleSettings":{"showBorder":true}},{"type":3,"content":{"version":"KqlItem/1.0","query":"let baseQuery = AzureDiagnostics \\r\\n| where Category == \\"kube-audit\\"\\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where TimeGenerated {timeframe}\\r\\n| where log_s has \\"exec\\"\\r\\n| project TimeGenerated, parse_json(log_s), ResourceId\\r\\n| project TimeGenerated,\\r\\n          AzureResourceId = ResourceId,\\r\\n          User = log_s[\\"user\\"],\\r\\n          StageTimestamp = todatetime(log_s[\\"stageTimestamp\\"]),\\r\\n          Timestamp = todatetime(log_s[\\"timestamp\\"]),\\r\\n          Stage = tostring(log_s[\\"stage\\"]),\\r\\n          RequestURI = tostring(log_s[\\"requestURI\\"]),\\r\\n          UserAgent = tostring(log_s[\\"userAgent\\"]),\\r\\n          Verb = tostring(log_s[\\"verb\\"]),\\r\\n          ObjectRef = log_s[\\"objectRef\\"],\\r\\n          ResponseStatus = log_s[\\"responseStatus\\"]\\r\\n| where ObjectRef.resource == \\"pods\\" and Verb == \\"create\\" and ResponseStatus.code == 101 and ObjectRef.subresource == \\"exec\\"\\r\\n| project operationTime = TimeGenerated,\\r\\n          RequestURI,\\r\\n          podName       = tostring(ObjectRef.name),\\r\\n          podNamespace  = tostring(ObjectRef.namespace),\\r\\n          username      = tostring(User.username),\\r\\n          AzureResourceId\\r\\n// Parse the exec command\\r\\n| extend commands =  extractall(@\\"command=([^\\\\&]*)\\", RequestURI)\\r\\n| extend commandsStr = url_decode(strcat_array(commands, \\" \\"))\\r\\n| project-away [\'commands\'], RequestURI\\r\\n| where username != \\"aksProblemDetector\\"\\r\\n;\\r\\nlet cached = materialize(baseQuery);\\r\\nlet execOperations = \\r\\ncached\\r\\n| summarize operationTime = min(operationTime), numberOfPerations = count() by name = commandsStr, username, podNamespace, podName, AzureResourceId\\r\\n| extend id = name\\r\\n| extend parentId = podName\\r\\n| project id, parentId, name, operationTime, numberOfPerations, podNamespace, username, AzureResourceId\\r\\n;\\r\\nlet podOperations = \\r\\ncached\\r\\n| summarize operationTime = min(operationTime), numberOfPerations = count() by name = podName, podNamespace, AzureResourceId\\r\\n| extend id = name\\r\\n| extend parentId = AzureResourceId\\r\\n| project id, parentId, name, operationTime, numberOfPerations, podNamespace, username = \\"\\", AzureResourceId\\r\\n;\\r\\nlet clusterOperations = \\r\\ncached\\r\\n| summarize operationTime = min(operationTime), numberOfPerations = count() by name = AzureResourceId\\r\\n| extend id = name\\r\\n| extend parentId = \\"\\"\\r\\n| project id, parentId, name, operationTime, numberOfPerations, username = \\"\\", podNamespace = \\"\\", AzureResourceId = name\\r\\n;\\r\\nunion clusterOperations, podOperations, execOperations","size":1,"title":"exec commands","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"visualization":"table","gridSettings":{"formatters":[{"columnMatch":"id","formatter":5},{"columnMatch":"parentId","formatter":5},{"columnMatch":"numberOfPerations","formatter":4,"formatOptions":{"palette":"blue","compositeBarSettings":{"labelText":"","columnSettings":[]}}},{"columnMatch":"AzureResourceId","formatter":5}],"hierarchySettings":{"idColumn":"id","parentColumn":"parentId","treeType":0,"expanderColumn":"name","expandTopLevel":false}}},"customWidth":"33","name":"exec commands","styleSettings":{"showBorder":true}},{"type":3,"content":{"version":"KqlItem/1.0","query":"SecurityAlert \\r\\n| where AlertType == \\"AKS_MaliciousContainerExec\\"\\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where TimeGenerated {timeframe}\\r\\n| project TimeGenerated, ResourceId, ExtendedProperties = todynamic(ExtendedProperties)\\r\\n| project TimeGenerated, ResourceId, [\\"Pod name\\"] = ExtendedProperties[\\"Pod name\\"], Command = ExtendedProperties[\\"Command\\"]","size":1,"title":"Related Microsoft Defender alerts details","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"gridSettings":{"sortBy":[{"itemKey":"TimeGenerated","sortOrder":1}]},"sortBy":[{"itemKey":"TimeGenerated","sortOrder":1}]},"customWidth":"33","name":"query - 9","styleSettings":{"showBorder":true}},{"type":3,"content":{"version":"KqlItem/1.0","query":"SecurityAlert \\r\\n| where AlertType == \\"AKS_MaliciousContainerExec\\"\\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where TimeGenerated {timeframe}\\r\\n| project name = extract(@\\"/MICROSOFT.CONTAINERSERVICE/MANAGEDCLUSTERS/(.+)\\", 1, ResourceId)\\r\\n| summarize alert = count() by name","size":1,"title":"AKS clusters with related Microsoft Defender alerts","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"visualization":"piechart"},"customWidth":"33","name":"query - 8","styleSettings":{"showBorder":true}},{"type":3,"content":{"version":"KqlItem/1.0","query":"let ascAlerts = \\r\\nunion withsource=_TableName *\\r\\n| where _TableName == \\"SecurityAlert\\"\\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where TimeGenerated {timeframe}\\r\\n| extend AlertType = column_ifexists(\\"AlertType\\", \\"\\")\\r\\n| where AlertType == \\"AKS_SensitiveMount\\"\\r\\n| extend ExtendedProperties = column_ifexists(\\"ExtendedProperties\\", todynamic(\\"\\"))\\r\\n| extend ExtendedProperties = parse_json(ExtendedProperties)\\r\\n| extend AlertLink = column_ifexists(\\"AlertLink\\", \\"\\")\\r\\n| summarize arg_min(TimeGenerated, AlertLink) by AzureResourceId = ResourceId, containerName = tostring(ExtendedProperties[\\"Container name\\"]), mountPath = tostring(ExtendedProperties[\\"Sensitive mount path\\"])\\r\\n;\\r\\nlet podOperations = \\r\\nAzureDiagnostics \\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where TimeGenerated {timeframe}\\r\\n| where Category == \\"kube-audit\\"\\r\\n| where log_s has \\"hostPath\\"\\r\\n| project TimeGenerated, parse_json(log_s), ResourceId\\r\\n//Parsing\\r\\n| project AzureResourceId = ResourceId, TimeGenerated,\\r\\n Verb = tostring(log_s[\\"verb\\"]),\\r\\n ObjectRef = log_s[\\"objectRef\\"],\\r\\n RequestObject = log_s[\\"requestObject\\"],\\r\\n ResponseStatus = log_s[\\"responseStatus\\"],\\r\\n ResponseObject = log_s[\\"responseObject\\"]\\r\\n//\\r\\n//Main query\\r\\n//\\r\\n| where ObjectRef.resource == \\"pods\\" and Verb == \\"create\\" and ResponseStatus.code startswith \\"20\\" and RequestObject has \\"hostPath\\"\\r\\n| extend volumes = RequestObject.spec.volumes\\r\\n| mvexpand volumes\\r\\n| extend mountPath = volumes.hostPath.path\\r\\n| where mountPath != \\"\\" \\r\\n| extend container = RequestObject.spec.containers\\r\\n| mvexpand container\\r\\n| extend  detectionTime = TimeGenerated\\r\\n| project detectionTime,\\r\\n          podName = ResponseObject.metadata.name,\\r\\n          podNamespace = ResponseObject.metadata.namespace,\\r\\n          containerName = container.name,\\r\\n          containerImage = container.image,\\r\\n          mountPath,\\r\\n          mountName = volumes.name,\\r\\n          AzureResourceId,\\r\\n          container\\r\\n| extend volumeMounts = container.volumeMounts\\r\\n| mv-expand volumeMounts\\r\\n| where tostring(volumeMounts.name) == tostring(mountName)\\r\\n| summarize operationTime = min(detectionTime) by AzureResourceId, name = tostring(podName),tostring(podNamespace), tostring(containerName), tostring(containerImage), tostring(mountPath), tostring(mountName)\\r\\n| extend id = strcat(name, \\";\\", AzureResourceId)\\r\\n| extend parent = AzureResourceId\\r\\n| join kind=leftouter (ascAlerts) on AzureResourceId, containerName, mountPath\\r\\n;\\r\\nlet cached = materialize(podOperations)\\r\\n;\\r\\nlet clusters = cached | distinct AzureResourceId\\r\\n;\\r\\n// Main query\\r\\ncached\\r\\n| union\\r\\n(\\r\\nclusters\\r\\n| project \\r\\n            name = toupper(AzureResourceId),\\r\\n            id = AzureResourceId,\\r\\n            parent = \\"\\"      \\r\\n)\\r\\n| project-away containerName1, mountPath1, TimeGenerated\\r\\n","size":1,"title":"hostPath mount","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"gridSettings":{"formatters":[{"columnMatch":"AzureResourceId","formatter":5},{"columnMatch":"name","formatter":13,"formatOptions":{"linkTarget":null,"showIcon":true}},{"columnMatch":"id","formatter":5},{"columnMatch":"parent","formatter":5},{"columnMatch":"AzureResourceId1","formatter":5},{"columnMatch":"AlertLink","formatter":7,"formatOptions":{"linkTarget":"Url"}}],"hierarchySettings":{"idColumn":"id","parentColumn":"parent","treeType":0,"expanderColumn":"name"}},"sortBy":[]},"customWidth":"66","name":"query - 10","styleSettings":{"showBorder":true}},{"type":3,"content":{"version":"KqlItem/1.0","query":"SecurityAlert \\r\\n| where AlertType == \\"AKS_SensitiveMount\\"\\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where TimeGenerated {timeframe}\\r\\n| project name = extract(@\\"/MICROSOFT.CONTAINERSERVICE/MANAGEDCLUSTERS/(.+)\\", 1, ResourceId)\\r\\n| summarize alert = count() by name","size":1,"title":"AKS clusters with related Microsoft Defender alerts","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"visualization":"piechart","sortBy":[]},"customWidth":"33","name":"query - 10","styleSettings":{"showBorder":true}},{"type":3,"content":{"version":"KqlItem/1.0","query":"let bindingOper = AzureDiagnostics\\r\\n| where Category == \\"kube-audit\\"\\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where TimeGenerated {timeframe}\\r\\n| where log_s has \\"clusterrolebindings\\"\\r\\n| project TimeGenerated, parse_json(log_s), ResourceId\\r\\n//Parsing\\r\\n| project AzureResourceId = ResourceId, TimeGenerated,\\r\\n RequestURI = tostring(log_s[\\"requestURI\\"]),\\r\\n User = log_s[\\"user\\"],\\r\\n Verb = tostring(log_s[\\"verb\\"]),\\r\\n ObjectRef = log_s[\\"objectRef\\"],\\r\\n RequestObject = log_s[\\"requestObject\\"],\\r\\n ResponseStatus = log_s[\\"responseStatus\\"]\\r\\n| where ObjectRef.resource == \\"clusterrolebindings\\" and Verb == \\"create\\" and ResponseStatus.code startswith \\"20\\" and RequestObject.roleRef.name == \\"cluster-admin\\"   \\r\\n| extend subjects = RequestObject.subjects\\r\\n| mv-expand subjects\\r\\n| project AzureResourceId, TimeGenerated, subjectName = tostring(subjects.name), subjectKind = tostring(subjects[\\"kind\\"]), bindingName = tostring(ObjectRef.name)\\r\\n| summarize operationTime = min(TimeGenerated) by AzureResourceId, subjectName, subjectKind, bindingName\\r\\n| extend id = strcat(subjectName, \\";\\", AzureResourceId)\\r\\n| extend parent = AzureResourceId\\r\\n;\\r\\nlet cached = materialize(bindingOper)\\r\\n;\\r\\nlet clusters = cached | distinct AzureResourceId\\r\\n;\\r\\n// Main query\\r\\ncached\\r\\n| union\\r\\n(\\r\\nclusters\\r\\n| project \\r\\n            name = AzureResourceId,\\r\\n            id = AzureResourceId,\\r\\n            parent = \\"\\"      \\r\\n)","size":1,"title":"Cluster-admin binding","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"visualization":"table","gridSettings":{"formatters":[{"columnMatch":"AzureResourceId","formatter":5},{"columnMatch":"id","formatter":5},{"columnMatch":"parent","formatter":5},{"columnMatch":"name","formatter":13,"formatOptions":{"linkTarget":null,"showIcon":true}}],"hierarchySettings":{"idColumn":"id","parentColumn":"parent","treeType":0,"expanderColumn":"name"}}},"customWidth":"66","name":"query - 5","styleSettings":{"showBorder":true}},{"type":3,"content":{"version":"KqlItem/1.0","query":"SecurityAlert \\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where TimeGenerated {timeframe}\\r\\n| where AlertType == \\"AKS_ClusterAdminBinding\\"\\r\\n| project name = extract(@\\"/MICROSOFT.CONTAINERSERVICE/MANAGEDCLUSTERS/(.+)\\", 1, ResourceId)\\r\\n| summarize count() by name","size":1,"title":"AKS clusters with related Microsoft Defender alerts","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"],"visualization":"piechart"},"customWidth":"33","name":"query - 11","styleSettings":{"showBorder":true}},{"type":3,"content":{"version":"KqlItem/1.0","query":"AzureDiagnostics\\r\\n| where Category == \\"kube-audit\\"\\r\\n| where tolower(ResourceId) in ({clustername})\\r\\n| where TimeGenerated {timeframe}\\r\\n| where log_s has \\"events\\"\\r\\n| project TimeGenerated, parse_json(log_s), ResourceId\\r\\n//Parsing\\r\\n| project AzureResourceId = ResourceId, \\r\\n TimeGenerated,\\r\\n SourceIPs = tostring(log_s[\\"sourceIPs\\"][0]),\\r\\n User = log_s[\\"user\\"],\\r\\n Verb = tostring(log_s[\\"verb\\"]),\\r\\n ObjectRef = log_s[\\"objectRef\\"],\\r\\n ResponseStatus = log_s[\\"responseStatus\\"]\\r\\n| where ObjectRef.resource == \\"events\\" and Verb == \\"delete\\" and ResponseStatus.code == 200\\r\\n| project TimeGenerated, AzureResourceId, username = tostring(User.username), ipAddr = tostring(SourceIPs), \\r\\n          eventName = tostring(ObjectRef.name), eventNamespace = tostring(ObjectRef.namespace), status = tostring(ResponseStatus.code)\\r\\n| summarize operationTime = min(TimeGenerated), eventNames = make_set(eventName, 10) by\\r\\n                                        AzureResourceId, \\r\\n                                        eventNamespace,\\r\\n                                        username,\\r\\n                                        ipAddr\\r\\n// Format the list of the event names\\r\\n| extend eventNames = substring(eventNames, 1 , strlen(eventNames) - 2)\\r\\n| extend eventNames = replace(\'\\"\', \\"\\", eventNames)\\r\\n| extend eventNames = replace(\\",\\", \\", \\", eventNames)","size":1,"title":"Delete events","queryType":0,"resourceType":"microsoft.operationalinsights/workspaces","crossComponentResources":["{workspaces}"]},"name":"query - 6","styleSettings":{"showBorder":true}}]},"conditionalVisibility":{"parameterName":"diagnosticClusters","comparison":"isEqualTo","value":"yes"},"name":"diagnosticData"},{"type":1,"content":{"json":"No Diagnostic Logs data in the selected workspaces. \\r\\nTo enable Diagnostic Logs for your AKS cluster: Go to your AKS cluster --> Diagnostic settings --> Add diagnostic setting --> Select \\"kube-audit\\" and send the data to your workspace.\\r\\n\\r\\nGet more details here: https://learn.microsoft.com/azure/aks/view-master-logs","style":"info"},"conditionalVisibility":{"parameterName":"diagnosticClusters","comparison":"isEqualTo","value":"no"},"name":"text - 4"}]},"conditionalVisibility":{"parameterName":"mainTab","comparison":"isEqualTo","value":"diagnostics"},"name":"diagnostics"}],"fromTemplateId":"sentinel-AksWorkbook","$schema":"https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json"}'
    version: '1.0'
    category: 'sentinel'
    sourceId: la.id
    tags: [
      'AksSecurityWorkbook'
      '1.2'
    ]
  }
}

resource omsKeyVaultAnalytics 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'KeyVaultAnalytics(${la.name})'
  location: location
  properties: {
    workspaceResourceId: la.id
  }
  plan: {
    name: 'KeyVaultAnalytics(${la.name})'
    product: 'OMSGallery/KeyVaultAnalytics'
    promotionCode: ''
    publisher: 'Microsoft'
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
            id: vnetSpoke::snetApplicationGateway.id
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'agw-frontend-ip-configuration'
        properties: {
          publicIPAddress: {
            id: pipPrimaryCluster.id
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
          keyVaultSecretId: kvsGatewaySslCert.properties.secretUri
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
              ipAddress: '10.240.4.4' // This is the IP address that our ingress controller will request
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
            id: resourceId('Microsoft.Network/applicationGateways/probes', 'agw-${clusterName}', 'probe-bu0001a0005-00.aks-ingress.contoso.com')
          }
          trustedRootCertificates: [
            {
              id: resourceId('Microsoft.Network/applicationGateways/trustedRootCertificates', 'agw-${clusterName}', 'root-cert-wildcard-aks-ingress-contoso')
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
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', 'agw-${clusterName}', 'agw-frontend-ip-configuration')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', 'agw-${clusterName}', 'agw-frontend-ports')
          }
          protocol: 'Https'
          sslCertificate: {
            id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', 'agw-${clusterName}', 'agw-${clusterName}-ssl-certificate')
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
          priority: 1
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', 'agw-${clusterName}', 'listener-https')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', 'agw-${clusterName}', 'bu0001a0005-00.aks-ingress.contoso.com')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', 'agw-${clusterName}', 'aks-ingress-contoso-backendpool-httpsettings')
          }
        }
      }
    ]
  }
  dependsOn: [
    kvMiAppGatewayKeyVaultReader_roleAssignment
    kvMiAppGatewaySecretsUserRole_roleAssignment
  ]
}

@description('The diagnostic settings configuration for the aks regulated cluster regional load balancer.')
resource agw_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: agw
  name: 'default'
  properties: {
    workspaceId: la.id
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
                      id: vnetSpoke::snetManagmentOps.id
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
        workspaceId: la.properties.customerId
      }
      protectedSettings: {
        workspaceKey: la.listKeys().primarySharedKey
      }
    }
  }

  resource extDependencyAgentLinux 'extensions' = {
    name: 'DependencyAgentLinux'
    properties: {
      publisher: 'Microsoft.Azure.Monitoring.DependencyAgent'
      type: 'DependencyAgentLinux'
      typeHandlerVersion: '9.10'
      autoUpgradeMinorVersion: true
    }
    dependsOn: [
      extOmsAgentForLinux
    ]
  }
}

resource paAksLinuxRestrictive 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: guid(psdAKSLinuxRestrictiveId, resourceGroup().name, clusterName)
  properties: {
    displayName: trim(take('[${clusterName}] ${reference(psdAKSLinuxRestrictiveId, '2020-09-01').displayName}', 125))
    policyDefinitionId: psdAKSLinuxRestrictiveId
    parameters: {
      effect: {
        value: 'audit'
      }
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
        ]
      }
    }
  }
}

resource paEnforceHttpsIngress 'Microsoft.Authorization/policyAssignments@2020-09-01' = {
  name: guid(pdEnforceHttpsIngressId, resourceGroup().name, clusterName)
  properties: {
    displayName: trim(take('[${clusterName}] ${reference(pdEnforceHttpsIngressId, '2020-09-01').displayName}', 125))
    policyDefinitionId: pdEnforceHttpsIngressId
    parameters: {
      effect: {
        value: 'deny'
      }
      excludedNamespaces: {
        value: []
      }
    }
  }
}

resource paEnforceInternalLoadBalancers 'Microsoft.Authorization/policyAssignments@2020-09-01' = {
  name: guid(pdEnforceInternalLoadBalancersId, resourceGroup().name, clusterName)
  properties: {
    displayName: trim(take('[${clusterName}] ${reference(pdEnforceInternalLoadBalancersId, '2020-09-01').displayName}', 125))
    policyDefinitionId: pdEnforceInternalLoadBalancersId
    parameters: {
      effect: {
        value: 'deny'
      }
      excludedNamespaces: {
        value: []
      }
    }
  }
}

resource paMustNotAutomountApiCreds 'Microsoft.Authorization/policyAssignments@2020-09-01' = {
  name: guid(pdMustNotAutomountApiCreds, resourceGroup().name, clusterName)
  properties: {
    displayName: trim(take('[${clusterName}] ${reference(pdMustNotAutomountApiCreds, '2020-09-01').displayName}', 125))
    policyDefinitionId: pdMustNotAutomountApiCreds
    parameters: {
      effect: {
        value: 'deny'
      }
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
          'flux-system' // Required by Flux
          'falco-system' // Required by Falco
          'osm-system' // Required by OSM
          'ingress-nginx' // Required by NGINX
          'cluster-baseline-settings' // Required by Key Vault CSI & Kured
        ]
      }
    }
  }
}

resource paMustUseSpecifiedLabels 'Microsoft.Authorization/policyAssignments@2020-09-01' = {
  name: guid(pdMustUseSpecifiedLabels, resourceGroup().name, clusterName)
  properties: {
    displayName: trim(take('[${clusterName}] ${reference(pdMustUseSpecifiedLabels, '2020-09-01').displayName}', 125))
    policyDefinitionId: pdMustUseSpecifiedLabels
    parameters: {
      effect: {
        value: 'audit'
      }
      labelsList: {
        value: [
          'pci-scope'
        ]
      }
    }
  }
}

resource paMustUseTheseExternalIps 'Microsoft.Authorization/policyAssignments@2020-09-01' = {
  name: guid(pdAllowedExternalIPsId, resourceGroup().name, clusterName)
  properties: {
    displayName: trim(take('[${clusterName}] ${reference(pdAllowedExternalIPsId, '2020-09-01').displayName}', 125))
    policyDefinitionId: pdAllowedExternalIPsId
    parameters: {
      effect: {
        value: 'deny'
      }
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
        ]
      }
      allowedExternalIPs: {
        value: [] // No external IPs allowed (LoadBalancer Service types do not apply to this policy)
      }
    }
  }
}

resource paApprovedContainerPortsOnly 'Microsoft.Authorization/policyAssignments@2020-09-01' = {
  name: guid(pdApprovedContainerPortsOnly, resourceGroup().name, clusterName)
  properties: {
    displayName: trim(take('[${clusterName}-a0005] ${reference(pdApprovedContainerPortsOnly, '2020-09-01').displayName}', 125))
    policyDefinitionId: pdApprovedContainerPortsOnly
    parameters: {
      effect: {
        value: 'audit'
      }
      excludedNamespaces: {
        value: []
      }
      namespaces: {
        value: [
          'a0005-i'
          'a0005-o'
        ]
      }
      allowedContainerPortsList: {
        value: [
          '8080' // ASP.net service listens on this
          '15000' // envoy proxy for service mesh
          '15003' // envoy proxy for service mesh
          '15010' // envoy proxy for service mesh
        ]
      }
    }
  }
}

resource paApprovedServicePortsOnly 'Microsoft.Authorization/policyAssignments@2020-09-01' = {
  name: guid(pdApprovedServicePortsOnly, resourceGroup().name, clusterName)
  properties: {
    displayName: trim(take('[${clusterName}] ${reference(pdApprovedServicePortsOnly, '2020-09-01').displayName}', 125))
    policyDefinitionId: pdApprovedServicePortsOnly
    parameters: {
      effect: {
        value: 'audit'
      }
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
          'osm-system'
        ]
      }
      allowedServicePortsList: {
        value: [
          '443' // ingress-controller
          '80' // flux source-controller and microservice workload
          '8080' // web-frontend workload
        ]
      }
    }
  }
}

@description('Applying the \'Kubernetes cluster containers should run with a read only root file system\' policy to the resource group.')
resource paRoRootFilesystem 'Microsoft.Authorization/policyAssignments@2020-09-01' = {
  name: guid(pdRoRootFilesystemId, resourceGroup().name, clusterName)
  properties: {
    displayName: trim(take('[${clusterName}] ${reference(pdRoRootFilesystemId, '2020-09-01').displayName}', 125))
    policyDefinitionId: pdRoRootFilesystemId
    parameters: {
      effect: {
        value: 'audit'
      }
      // Not all workloads support this. E.g. ASP.NET requires a non-readonly root file system to handle request buffering when there is memory pressure.
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
        ]
      }
    }
  }
}

resource paBlockDefaultNamespace 'Microsoft.Authorization/policyAssignments@2020-09-01' = {
  name: guid(pdDisallowNamespaceUsageId, resourceGroup().name, clusterName)
  properties: {
    displayName: trim(take('[${clusterName}] ${reference(pdDisallowNamespaceUsageId, '2020-09-01').displayName}', 125))
    policyDefinitionId: pdDisallowNamespaceUsageId
    parameters: {
      effect: {
        value: 'deny'
      }
      excludedNamespaces: {
        value: []
      }
    }
  }
}

resource paEnforceResourceLimits 'Microsoft.Authorization/policyAssignments@2020-09-01' = {
  name: guid(pdEnforceResourceLimitsId, resourceGroup().name, clusterName)
  properties: {
    displayName: trim(take('[${clusterName}] ${reference(pdEnforceResourceLimitsId, '2020-09-01').displayName}', 125))
    policyDefinitionId: pdEnforceResourceLimitsId
    parameters: {
      effect: {
        value: 'audit'
      }
      cpuLimit: {
        value: '1500m'
      }
      memoryLimit: {
        value: '2Gi'
      }
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
          'flux-system' /* Flux extension, not all containers have limits defined by Microsoft */
        ]
      }
    }
  }
}

resource paEnforceImageSource 'Microsoft.Authorization/policyAssignments@2020-03-01' = {
  name: guid(pdEnforceImageSourceId, resourceGroup().name, clusterName)
  properties: {
    displayName: trim(take('[${clusterName}] ${reference(pdEnforceImageSourceId, '2020-09-01').displayName}', 125))
    policyDefinitionId: pdEnforceImageSourceId
    parameters: {
      allowedContainerImagesRegex: {
        value: '${acrName}\\.azurecr\\.io\\/live\\/.+$|mcr\\.microsoft\\.com\\/oss\\/(openservicemesh\\/init:|envoyproxy\\/envoy:).+$'
      }
      effect: {
        value: 'deny'
      }
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
          'flux-system'
        ]
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

module ensureClusterIdentityHasRbacToSelfManagedResources 'modules/ensureClusterIdentityHasRbacToSelfManagedResources.bicep' = {
  name: 'ensureClusterIdentityHasRbacToSelfManagedResources'
  scope: spokeResourceGroup
  params: {
    miClusterControlPlanePrincipalId: miClusterControlPlane.properties.principalId
    clusterControlPlaneIdentityName: miClusterControlPlane.name
    vnetSpokeName: vnetSpoke.name
    location: location
  }
}

resource mc 'Microsoft.ContainerService/managedClusters@2022-10-02-preview' = {
  name: clusterName
  location: location
  tags: {
    'Data classification': 'Confidential'
    'Business unit': 'BU0001'
    'Business criticality': 'Business unit-critical'
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: uniqueString(subscription().subscriptionId, resourceGroup().id, clusterName)
    agentPoolProfiles: [
      {
        name: 'npsystem'
        count: 3
        vmSize: 'Standard_DS2_v2'
        osDiskSizeGB: 80
        osDiskType: 'Ephemeral'
        osType: 'Linux'
        osSKU: 'Ubuntu'
        minCount: 3
        maxCount: 4
        vnetSubnetID: vnetSpoke::snetClusterSystemNodePools.id
        enableAutoScaling: true
        type: 'VirtualMachineScaleSets'
        mode: 'System'
        scaleSetPriority: 'Regular'
        scaleSetEvictionPolicy: 'Delete'
        orchestratorVersion: kubernetesVersion
        enableNodePublicIP: false
        maxPods: 30
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
        vmSize: 'Standard_DS3_v2'
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
        maxPods: 30
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
        vmSize: 'Standard_DS3_v2'
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
    nodeResourceGroup: 'rg-${clusterName}-nodepools'
    enableRBAC: true
    enablePodSecurityPolicy: false
    maxAgentPools: 3
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'azure'
      outboundType: 'userDefinedRouting'
      loadBalancerSku: 'standard'
      loadBalancerProfile: json('null')
      serviceCidr: '172.16.0.0/16'
      dnsServiceIP: '172.16.0.10'
      dockerBridgeCidr: '172.18.0.1/16'
    }
    aadProfile: {
      managed: true
      enableAzureRBAC: false
      adminGroupObjectIDs: [
        clusterAdminAadGroupObjectId
      ]
      tenantID: k8sControlPlaneAuthorizationTenantId
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
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${miClusterControlPlane.id}': {
      }
    }
  }
  sku: {
    name: 'Basic'
    tier: 'Paid'
  }
  dependsOn: [
    omsContainerInsights
    ensureClusterIdentityHasRbacToSelfManagedResources

    // You want policies created before cluster because they take some time to be made available and we want them
    // to apply to your cluster as soon as possible. Nothing in this cluster "technically" depends on these existing,
    // just trying to get coverage as soon as possible.
    paAksLinuxRestrictive
    paEnforceHttpsIngress
    paEnforceInternalLoadBalancers
    paMustNotAutomountApiCreds
    paMustUseSpecifiedLabels
    paMustUseTheseExternalIps
    paApprovedContainerPortsOnly
    paApprovedServicePortsOnly
    paRoRootFilesystem
    paBlockDefaultNamespace
    paEnforceResourceLimits
    paEnforceImageSource

    vmssJumpboxes // Ensure jumboxes are available to use as soon as possible, don't wait until cluster is created.
  ]
}

resource mc_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: mc
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

@description('Workload identity service account federation for the ingress controller\'s identity which is used to acquire access tokens to read TLS certs from Azure Key Vault.')
resource fic 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2022-01-31-preview' = {
  name: 'ingress-controller'
  parent: miIngressController
  properties: {
    audiences: [
      'api://AzureADTokenExchange'
    ]
    issuer: mc.properties.oidcIssuerProfile.issuerURL
    subject: 'system:serviceaccount:ingress-nginx:ingress-nginx'
  }
}

@description('Grant kubelet managed identity with container registry pull role permissions; this allows the AKS Cluster\'s kubelet managed identity to pull images from this container registry.')
resource crMiKubeletContainerRegistryPullRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: acr
  name: guid(resourceGroup().id, mc.id, containerRegistryPullRole.id)
  properties: {
    description: 'Allows AKS to pull container images from this ACR instance.'
    roleDefinitionId: containerRegistryPullRole.id
    principalId: mc.properties.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
}

@description('Grant Azure Monitor (fka as OMS) Agent\'s managed identity with publisher metrics role permissions; this allows the AMA\'s identity to publish metrics in Container Insights.')
resource mcAmaAgentMonitoringMetricsPublisherRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(mc.id, 'amagent', monitoringMetricsPublisherRole.id)
  properties: {
    roleDefinitionId: monitoringMetricsPublisherRole.id
    principalId: mc.properties.addonProfiles.omsagent.identity.objectId
    principalType: 'ServicePrincipal'
  }
}

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
      mc.id
    ]
    severity: 3
    windowSize: 'PT5M'
    muteActionsDuration: null
    overrideQueryTimeRange: 'P2D'
  }
  dependsOn: [
    la
  ]
}

resource maNodeCpuUtilizationHighCI1 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Node CPU utilization high for ${clusterName} CI-1'
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
  name: 'Node working set memory utilization high for ${clusterName} CI-2'
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
  name: 'Jobs completed more than 6 hours ago for ${clusterName} CI-11'
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
  name: 'Container CPU usage high for ${clusterName} CI-9'
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
  name: 'Container working set memory usage high for ${clusterName} CI-10'
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
  name: 'Pods in failed state for ${clusterName} CI-4'
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
  name: 'Disk usage high for ${clusterName} CI-5'
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
  name: 'Nodes in not ready status for ${clusterName} CI-3'
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
  name: 'Containers getting OOM killed for ${clusterName} CI-6'
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
  name: 'Persistent volume usage high for ${clusterName} CI-18'
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
  name: 'Pods not in ready state for ${clusterName} CI-8'
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
  name: 'Restarting container count for ${clusterName} CI-7'
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

// Ensures that flux extension is installed.
resource mcFlux_extension 'Microsoft.KubernetesConfiguration/extensions@2021-09-01' = {
  scope: mc
  name: 'flux'
  properties: {
    extensionType: 'microsoft.flux'
    autoUpgradeMinorVersion: true
    releaseTrain: 'Stable'
    scope: {
      cluster: {
        releaseNamespace: 'flux-system'
      }
    }
    configurationSettings: {
      'helm-controller.enabled': 'false'
      'source-controller.enabled': 'true'
      'kustomize-controller.enabled': 'true'
      'notification-controller.enabled': 'false'
      'image-automation-controller.enabled': 'false'
      'image-reflector-controller.enabled': 'false'
    }
    configurationProtectedSettings: {}
  }
  dependsOn: [
    crMiKubeletContainerRegistryPullRole_roleAssignment
    fic
  ]
}

// Bootstraps your cluster using content from your repo.
resource mc_fluxConfiguration 'Microsoft.KubernetesConfiguration/fluxConfigurations@2022-03-01' = {
  scope: mc
  name: 'bootstrap'
  properties: {
    scope: 'cluster'
    namespace: 'flux-system'
    sourceKind: 'GitRepository'
    gitRepository: {
      url: gitOpsBootstrappingRepoHttpsUrl
      timeoutInSeconds: 180
      syncIntervalInSeconds: 300
      repositoryRef: {
        branch: gitOpsBootstrappingRepoBranch
        tag: null
        semver: null
        commit: null
      }
      sshKnownHosts: ''
      httpsUser: null
      httpsCACert: null
      localAuthRef: null
    }
    kustomizations: {
      unified: {
        path: './cluster-manifests'
        dependsOn: []
        timeoutInSeconds: 300
        syncIntervalInSeconds: 300
        retryIntervalInSeconds: 300
        prune: true
        force: false
      }
    }
  }
  dependsOn: [
    mcFlux_extension
    crMiKubeletContainerRegistryPullRole_roleAssignment
  ]
}

/*** OUTPUTS ***/

output agwName string = agw.name
output aksClusterName string = clusterName
