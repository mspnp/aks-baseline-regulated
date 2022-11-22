# End-to-End Validation

Now that you have a [simulated regulated workload deployed](./13-workload.md), you can start validating and exploring this reference implementation of the [AKS Baseline Cluster for Regulated Workloads](/).

## Validate the workload is deployed

This section will help you to validate the workload is exposed correctly and responding to HTTPS requests.

### Steps

1. Get the public IP of Azure Application Gateway.

   ```bash
   APPGW_PUBLIC_IP=$(az deployment group show -g rg-enterprise-networking-spokes -n spoke-BU0001A0005-01 --query properties.outputs.appGwPublicIpAddress.value -o tsv)
   ```

1. Create a DNS `A` Record 🛑

   > :bulb: You can simulate this via a local hosts file modification.

   Map the Azure Application Gateway public IP address to the application domain name. To do that, please edit your hosts file (`C:\Windows\System32\drivers\etc\hosts` or `/etc/hosts`) and add the following record to the end: `${APPGW_PUBLIC_IP} bicycle.contoso.com`

1. Browse to the site (e.g. <https://bicycle.contoso.com>).

   > :bulb: A TLS warning will be present due to using a self-signed certificate.

   > :bulb: Your first hit might result in a `upstream request timeout` response. There is a relatively low timeout on the workloads, and the request chain suffers from a "cold start" perspective. If you do get that, just refresh the page.

1. Review the emitted page details.

   This page shows a series of attempted network traffic attempts in your cluster. Due to Azure Firewall, NSGs, service mesh rules, and Kuberentes Network Policies, only a select number of requests will be successful, the rest will be blocked. Generally speaking, the allowed network flow is Ingress -> web-frontend -> microservice-a -> microservice-b -> microservice-c. All other attempted connections are denied. Likewise, most Internet-bound traffic was denied, and only microservice-a was able to make the public request.

## Validate Web Application Firewall functionality

Your workload is placed behind a Web Application Firewall (WAF), which has rules designed to stop intentionally malicious activity. You can test this by triggering one of the built-in rules with a request that looks malicious.

> :bulb: This reference implementation enables the built-in OWASP 3.2 ruleset, in **Prevention** mode.

### Steps

1. Browse to the site with the following appended to the URL: `?sql=DELETE%20FROM` (e.g. <https://bicycle.contoso.com/?sql=DELETE%20FROM>).
1. Observe that your request was blocked by Application Gateway's WAF rules and your workload never saw this potentially dangerous request.

For a more exhaustive WAF test and validation experience, try the [Azure Web Applicationg Firewall Security Protection and Detection Lab](https://techcommunity.microsoft.com/t5/azure-network-security/tutorial-overview-azure-web-application-firewall-security/ba-p/2030423).

### Next step

:arrow_forward: [Access resource logs & Microsoft Defender for Cloud data](./15-validation-logs.md)
