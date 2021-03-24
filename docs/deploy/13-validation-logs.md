# Access Resource Logs & Security Center Data

Your infrastructure and [workload is emitting logs](./13-validation.md), here are a few key logs you may wish to consider being familiar with and/or building [log-based queries](https://docs.microsoft.com/azure/azure-monitor/logs/get-started-queries) around. Below are some a few queries to get you started exploring the captured data.

You can access these logs all directly from the attached Log Analytics workspace(s), but when you do you'll need to filter to specific resources. For simplicity the steps below direct you to the pre-filtered view offered by the Azure Portal when viewing within the context of each service.

Remember, since this implementation builds on the AKS Baseline, [validations performed there](https://github.com/mspnp/aks-secure-baseline/blob/main/10-validation.md#validate-azure-monitor-for-containers-prometheus-metrics) such as viewing Prometheus metrics and Kured logs are also applicable to this cluster.

## Azure Firewall

Azure Firewall is the last network control point in your architecture. It captures logs for traffic that is allowed and denied.

1. In the Azure Portal, navigate to your Azure Firewall resource.
1. Click on **Logs**.

### View traffic blocked by Azure Firewall

Your Azure Firewall has already blocked traffic originating in the cluster headed to **https://example.org** as part of the workload. To see those denied requests, execute the following query:

```kusto
AzureDiagnostics
| where Category == "AzureFirewallApplicationRule"
| where msg_s contains "example.org:443"
| order by TimeGenerated desc
```

### View Azure Firewall DNS proxy logs

Your Azure Firewall is acting as a DNS proxy for your spokes. To see DNS requests that the firewall has serviced, you can execute the following query.

```kusto
AzureDiagnostics
| where Category == "AzureFirewallDnsProxy"
| parse kind=regex msg_s with "DNS Request: " SourceIp ":.+ IN " RequestedName " ..p.+s"
| project TimeGenerated, SourceIp, RequestedName
| order by TimeGenerated desc
```

## Azure Container Registry

1. In the Azure Portal, navigate to your Azure Container Registry resource.
1. Click on **Logs**.

### View image imports

To view all the image imports that have happened against your container registry, you can execute the following query.

ContainerRegistryRepositoryEvents
| where OperationName == "importImage"
| order by TimeGenerated desc

### View image pulls

To view all the pulls that have happened against your container registry, you can execute the following query.

```kusto
ContainerRegistryRepositoryEvents
| where OperationName == "Pull"
| order by TimeGenerated desc
```

Unless you performed some additional steps beyond this walkthrough's instructions, you'll notice that the value for all of the records share the same `Identity` -- that is the Object ID of the AKS cluster's managed identity, specifically kubelet (`<your-cluster-name>-agentpool`).

### Azure Defender for container registries

If you execute the following query, you'll see all denied requests for access to your container registry. Your container registry is private, and most (if not all) of this traffic is originating from Azure Defender for container registries -- which does not support private container registries.

```kusto
ContainerRegistryLoginEvents 
| where ResultDescription == "403"
| order by TimeGenerated desc
```

### Image quarantine violation alert

If you executed the optional extra import command on the [image quarantine step page](./10-pre-bootstrap.md), which bypasses the quarantine, you'll be able to see that alert.

1. Open the [Azure Monitor Alerts Summary page](https://portal.azure.com/#blade/Microsoft_Azure_Monitoring/AlertsManagementSummaryBlade) in the Azure Portal.
1. Find the alert and click on **View query results** which will show you the offending images' details.

## AKS Cluster

Monitoring your cluster is critical, especially when you're running a production cluster. Azure Monitor is configured to surface cluster logs, here you can see those logs as they are generated. [Azure Monitor for containers](https://docs.microsoft.com/azure/azure-monitor/insights/container-insights-overview) is configured on this cluster for this purpose.

1. In the Azure Portal, navigate to your AKS cluster resource.
1. Select **Logs**.
1. You can click **Queries** to see and execute some common log queries.

### Kubernetes API Server access logs

This reference implementation logs all AKS control plane interactions in the associated Log Analytics workspace. Specifically this is enabled through the use of `kube-audit-admin` Diagnostics setting that was enabled on the cluster.

```kusto
AzureDiagnostics 
| where Category == 'kube-audit-admin'
| order by TimeGenerated desc
```

This returns all Kubernetes API Server interaction happening in your cluster, other than most `GET` requests. Basically any interaction that might potentially have the capability to modifying the system. Even an "idle" cluster can fill this log very quickly (don't be surprised to see over 200 messages in a 30 minute window). Most regulations do not require it, but if you disable `kube-audit-admin` and instead simply enable `kube-audit` the system will _also_ log all of the `GET` (read) requests as well. This will _dramatically_ increase the number of logs, but you will then see 100% of the requests to the Kubernetes API Server. _Never enable both at the same time._

For example, if you wanted to see all interactions you had while going through this walkthrough, you can execute the following, replacing with the user you used while performing the bootstrapping.

```kusto
AzureDiagnostics
| where Category == 'kube-audit-admin'
| where log_s contains '"username":"bu0001a000500-admin@yourdomain.com"'
```

### Workload logs

The example workload uses the standard dotnet logger interface, which are captured in `ContainerLogs` in Azure Monitor. You could also include additional logging and telemetry frameworks in your workload, such as Application Insights. Execute the following query to view application logs.

```kusto
ContainerLog
| where Image contains "chain-api"
| order by TimeGenerated desc
```

### Azure Policy logs

Azure policy definitions sync with your cluster about once every 15 minutes. To see when they sync you can execute the following query.

```kusto
ContainerLog
| where Image contains "policy-kubernetes-addon"
| where LogEntry contains "Syncing policies with cluster"
| order by TimeGenerated desc
```

And audit results will be sent to Azure Policy about once every 30 minutes. To see when they sync you can execute the following query.

```kusto
ContainerLog
| where Image contains "policy-kubernetes-addon"
| where LogEntry contains "Sending audit result"
| order by TimeGenerated desc
```

## Azure Application Gateway

Azure Application Gateway will log key information such as requests, routing, backend health, and even your WAF rule blocks.

1. In the Azure Portal, navigate to your Azure Application Gateway resource.
1. Select **Logs**.

### Access logs

All traffic that the gateway services can be viewed via the following query. This includes source and destination information.

```kusto
AzureDiagnostics 
| where Category == "ApplicationGatewayAccessLog"
| order by TimeGenerated desc
```

### View Web Application Firewall (WAF) logs

Blocked requests (along with other gateway data) will be visible in the attached Log Analytics workspace. Execute the following query to show WAF logs, for example. If you executed the intentionally malicious request on the previous page, you should already see logs in here.

```kusto
AzureDiagnostics 
| where Category == "ApplicationGatewayFirewallLog"
| order by TimeGenerated desc
```

## Azure Key Vault

Azure Key Vault will log all operations with every secret and certificate in the vault.

1. In the Azure Portal, navigate to your Azure Key Vault resource.
1. Select **Logs**.

### View all requests for secrets

Both your cluster and Application Gateway will be pulling secrets from your Key Vault. To see that traffic, you can execute the following query.

```kusto
AzureDiagnostics 
| where OperationName == "SecretGet"
| order by TimeGenerated desc
```

You should see requests for `sslcert` & `appgw-ingress-internal-aks-ingress-contoso-com-tls` from Application Gateway and `ingress-internal-aks-ingress-contoso-com-tls` from your AKS cluster.

Other common operations you might be interested in are `SecretResourcePut`, `Authentication`, and `CertificateImport`.

## Azure Security Center

### Regulatory compliance

If your subscription has the **Azure Security Benchmark** Azure Policy initiative applied, and **Industry & regulatory standards** enabled (e.g. **PCI DSS 3.2.1**), the **Regulatory compliance** dashboard will allow you to see compliance status for controls that have been mapped by Azure to the specific standard. The view is updated about once every 24 hours, this includes its initial scan. So if you enabled this as part of the walkthrough (steps found on the [Subscription page](./04-subscription.md)), you may not yet see any content in here.

1. Open the [Regulatory compliance dashboard](https://portal.azure.com/#blade/Microsoft_Azure_Security/SecurityMenuBlade/22) in Security Center.
1. Review the Industry summary and any recommendations.

### Review Security Alerts

Azure Defender for kubernetes reviews your cluster's logs and detects behavior that might be undesired. Those alerts surface in the Azure Resource Graph (`securityresources` -> `microsoft.security/locations/alerts`) and also in Security Center in the Azure Portal. Within about 24 hours of your cluster being up and running, you should start to see some alerts show up (Low and Medium).

1. Open the [Security Alerts view](https://portal.azure.com/#blade/Microsoft_Azure_Security/SecurityMenuBlade/7) in Azure Security Center.
1. View the alerts, and optionally add a _Filter_ for _Affected resource_ being your newly created cluster.

## Azure Sentinel

Data from Log Analytic on the networking and cluster infrastructure are being delivered to Azure Sentinel.

1. Open the [Azure Sentinel hub](https://portal.azure.com/#blade/HubsExtension/BrowseResource/resourceType/microsoft.securityinsightsarg%2Fsentinel) on the Azure Portal.
1. Select a Log Analytics workspace (networking or cluster)

From here you can view Alerts, Incidents, start a Hunting session, view/add related Workbooks (such as the **Azure Kubernetes Service (AKS) Security** workbook), etc.

### Next step

:arrow_forward: [Clean Up Azure Resources](./14-cleanup.md)
