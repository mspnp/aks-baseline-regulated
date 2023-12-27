# Microsoft Entra Conditional Access

Microsoft Entra Conditional Access supports policies that apply directly to Kubernetes cluster access. In your policy you can apply any of the standard conditions and access controls, and scope them to apply specifically for your cluster's _Azure Kubernetes Service AAD Server_ cloud app.

For example, you could require that devices accessing the API Server are being performed exclusively from devices marked as compliant, only from select or trusted locations, only from select OSes, etc. Conditional access will often then be applied when connecting to your cluster from [your jump box](./deploy/06-aks-jumpboximage.md), ensuring that the jump box itself and the user performing the action have met core conditional criteria to perform any API Server interaction.

Work with your Conditional Access administrator [to apply a policy](https://learn.microsoft.com/azure/aks/access-control-managed-azure-ad) that helps you achieve your access governance requirements. In addition to the portal, you can also perform the assignment via the AzureAD Windows PowerShell module.

Remember to test all conditional access policies using a safe and controlled rollout procedure before applying to all users. Paired with [Microsoft Entra JIT access](https://learn.microsoft.com/azure/aks/access-control-managed-azure-ad#use-conditional-access-with-microsoft-entra-id-and-aks), this provides a very robust access control solution for your private cluster.

> :notebook: See [Azure Architecture Center guidance for PCI-DSS 3.2.1 Requirement 8.2 in AKS](https://learn.microsoft.com/azure/architecture/reference-architectures/containers/aks-pci/aks-pci-identity#requirement-82).

## Applying via Windows PowerShell

For many administrators, PowerShell is already an understood scripting tool. The following example shows how to use the Azure AD PowerShell module to apply a Conditional Access policy.

> Note: Azure AD Powershell is planned for deprecation on March 30, 2024, including these following instructions. For more details on the deprecation plans, see the [deprecation update](https://techcommunity.microsoft.com/t5/microsoft-entra-azure-ad-blog/important-azure-ad-graph-retirement-and-powershell-module/ba-p/3848270). We encourage you to continue migrating to [Microsoft Graph PowerShell](https://learn.microsoft.com/powershell/microsoftgraph/overview), which is the recommended module for interacting with Microsoft Entra ID.

```powershell
Install-Module -Name AzureAD -Force -Scope CurrentUser

# Must see AzureAD listed at a version >= 2.0.2.106
Get-InstalledModule -Name AzureAD

Connect-AzureAD -TenantId <your-tenant-guid>

$conditions = New-Object -TypeName Microsoft.Open.MSGraph.Model.ConditionalAccessConditionSet
$conditions.Applications = New-Object -TypeName Microsoft.Open.MSGraph.Model.ConditionalAccessApplicationCondition
$conditions.Applications.IncludeApplications = "<your-cluster's-server-app-guid>"
$conditions.Users = New-Object -TypeName Microsoft.Open.MSGraph.Model.ConditionalAccessUserCondition
$conditions.Users.IncludeUsers = "All" # Or do per-group policies based on risk profile of those groups.
# Additional $conditions as desired

$controls = New-Object -TypeName Microsoft.Open.MSGraph.Model.ConditionalAccessGrantControls
# Configure $controls as desired

New-AzureADMSConditionalAccessPolicy -DisplayName "AKS API Server <server name> Access Policy" -State "on" -Conditions $conditions -GrantControls $controls
```

For more examples, see [Configure Conditional Access policies using Azure AD PowerShell](https://github.com/Azure-Samples/azure-ad-conditional-access-apis/tree/main/01-configure/powershell)

### Alternatives to Windows PowerShell

Microsoft Entra Conditional Access policies can be managed in the following ways if Windows PowerShell is not aligned with your preferred toolset.

* Within the Microsoft Entra admin center directly
* [Microsoft Graph API](https://github.com/Azure-Samples/azure-ad-conditional-access-apis/tree/main/01-configure/graphapi), including advanced flows like [using Logic Apps to facilitate deployment](https://github.com/Azure-Samples/azure-ad-conditional-access-apis/tree/main/01-configure/templates)

## Next Steps

* See additional [Authentication & Authorization considerations](./additional-considerations.md#authentication--authorization)
* [Prep for Microsoft Entra Integration](./deploy/03-aad.md)
