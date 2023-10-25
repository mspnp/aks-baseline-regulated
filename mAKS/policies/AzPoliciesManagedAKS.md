# LZ Policies Managed AKS

## General
**Policy Name** | **Description** | **Scope** | **Policy ID** |  **Parameters** | **Effect** | **Assignment** | **Comments** |
|------|----------------|------------|----------------|------------|----------------|--------------|-----|
| [Allowed Resource types](need link) | Security Baseline for Kubernetes | Management  |  [Azure Security Baseline for Azure Kubernetes Service](https://learn.microsoft.com/en-us/security/benchmark/azure/baselines/aks-security-baseline) | N/A | Deny | N/A | N/A |
## AKS

**Policy Name** | **Description** | **Scope** | **Policy ID** |  **Parameters** | **Effect** | **Assignment** | **Comments** |
|------|----------------|------------|----------------|------------|----------------|--------------|-----|
| [Security Baseline for Kubernetes(?)](need link) | Security Baseline for Kubernetes | Management  |  [Azure Security Baseline for Azure Kubernetes Service](https://learn.microsoft.com/en-us/security/benchmark/azure/baselines/aks-security-baseline) | N/A | Deny | N/A | N/A |
| [Kubernetes clusters should not allow privileged containers](https://portal.azure.com/#view/Microsoft_Azure_Policy/PolicyDetailBlade/definitionId/%2Fproviders%2FMicrosoft.Authorization%2FpolicyDefinitions%2F95edb821-ddaf-4404-9732-666045e056b4) | Do not allow privileged containers creation in a Kubernetes cluster. This recommendation is part of CIS 5.2.1 which is intended to improve the security of your Kubernetes environments. This policy is generally available for Kubernetes Service (AKS), and preview for Azure Arc enabled Kubernetes. For more information, see https://aka.ms/kubepolicydoc. | Subscription |  /providers/Microsoft.Authorization/policyDefinitions/95edb821-ddaf-4404-9732-666045e056b4 | N/A | Deny | N/A | N/A |
| [Kubernetes clusters should not allow container privilege escalation](https://portal.azure.com/#view/Microsoft_Azure_Policy/PolicyDetailBlade/definitionId/%2Fproviders%2FMicrosoft.Authorization%2FpolicyDefinitions%2F1c6e92c9-99f0-4e55-9cf2-0c234dc48f99) | Do not allow containers to run with privilege escalation to root in a Kubernetes cluster. This recommendation is part of CIS 5.2.5 which is intended to improve the security of your Kubernetes environments. This policy is generally available for Kubernetes Service (AKS), and preview for Azure Arc enabled Kubernetes. For more information, see https://aka.ms/kubepolicydoc. | Subscription |  /providers/Microsoft.Authorization/policyDefinitions/1c6e92c9-99f0-4e55-9cf2-0c234dc48f99 | N/A | Deny | N/A | N/A |
| [Kubernetes cluster pods should only use approved host network and port range](https://portal.azure.com/#view/Microsoft_Azure_Policy/PolicyDetailBlade/definitionId/%2Fproviders%2FMicrosoft.Authorization%2FpolicyDefinitions%2F82985f06-dc18-4a48-bc1c-b9f4f0098cfe) | Restrict pod access to the host network and the allowable host port range in a Kubernetes cluster. This recommendation is part of CIS 5.2.4 which is intended to improve the security of your Kubernetes environments. This policy is generally available for Kubernetes Service (AKS), and preview for Azure Arc enabled Kubernetes. For more information, see https://aka.ms/kubepolicydoc. | Subscription |  /providers/Microsoft.Authorization/policyDefinitions/1c6e92c9-99f0-4e55-9cf2-0c234dc48f99 | N/A | Deny | N/A | N/A |
| [Kubernetes cluster pods should only use approved host network and port range](https://portal.azure.com/#view/Microsoft_Azure_Policy/PolicyDetailBlade/definitionId/%2Fproviders%2FMicrosoft.Authorization%2FpolicyDefinitions%2F82985f06-dc18-4a48-bc1c-b9f4f0098cfe) | Restrict pod access to the host network and the allowable host port range in a Kubernetes cluster. This recommendation is part of CIS 5.2.4 which is intended to improve the security of your Kubernetes environments. This policy is generally available for Kubernetes Service (AKS), and preview for Azure Arc enabled Kubernetes. For more information, see https://aka.ms/kubepolicydoc. | Subscription |  /providers/Microsoft.Authorization/policyDefinitions/1c6e92c9-99f0-4e55-9cf2-0c234dc48f99 | N/A | Deny | N/A | N/A |
| [Kubernetes cluster pods should only use approved host network and port range](https://portal.azure.com/#view/Microsoft_Azure_Policy/PolicyDetailBlade/definitionId/%2Fproviders%2FMicrosoft.Authorization%2FpolicyDefinitions%2F82985f06-dc18-4a48-bc1c-b9f4f0098cfe) | Restrict pod access to the host network and the allowable host port range in a Kubernetes cluster. This recommendation is part of CIS 5.2.4 which is intended to improve the security of your Kubernetes environments. This policy is generally available for Kubernetes Service (AKS), and preview for Azure Arc enabled Kubernetes. For more information, see https://aka.ms/kubepolicydoc. | Subscription |  /providers/Microsoft.Authorization/policyDefinitions/1c6e92c9-99f0-4e55-9cf2-0c234dc48f99 | N/A | Deny | N/A | N/A |

## KeyVault

**Policy Name** | **Description** | **Scope** | **Policy ID** |  **Parameters** | **Effect** | **Assignment** | **Comments** |
|------|----------------|------------|----------------|------------|----------------|--------------|-----|
| [Security baseline for Azure Kubernetes Service](need link) | N/A | MG: SHB |  [Azure Security Baseline for Azure Kubernetes Service](https://learn.microsoft.com/en-us/security/benchmark/azure/baselines/aks-security-baseline) | N/A | Deny | N/A | N/A |
| [Security baseline for Azure Kubernetes Service](need link) | N/A | MG: SHB |  [Azure Security Baseline for Azure Kubernetes Service](https://learn.microsoft.com/en-us/security/benchmark/azure/baselines/aks-security-baseline) | N/A | Deny | N/A | N/A |
| [Security baseline for Azure Kubernetes Service](need link) | N/A | MG: SHB |  [Azure Security Baseline for Azure Kubernetes Service](https://learn.microsoft.com/en-us/security/benchmark/azure/baselines/aks-security-baseline) | N/A | Deny | N/A | N/A |

## ACR

**Policy Name** | **Description** | **Scope** | **Policy ID** |  **Parameters** | **Effect** | **Assignment** | **Comments** |
|------|----------------|------------|----------------|------------|----------------|--------------|-----|
| [Security baseline for Azure Kubernetes Service](need link) | N/A | MG: SHB |  [Azure Security Baseline for Azure Kubernetes Service](https://learn.microsoft.com/en-us/security/benchmark/azure/baselines/aks-security-baseline) | N/A | Deny | N/A | N/A |
| [Security baseline for Azure Kubernetes Service](need link) | N/A | MG: SHB |  [Azure Security Baseline for Azure Kubernetes Service](https://learn.microsoft.com/en-us/security/benchmark/azure/baselines/aks-security-baseline) | N/A | Deny | N/A | N/A |
| [Security baseline for Azure Kubernetes Service](need link) | N/A | MG: SHB |  [Azure Security Baseline for Azure Kubernetes Service](https://learn.microsoft.com/en-us/security/benchmark/azure/baselines/aks-security-baseline) | N/A | Deny | N/A | N/A |

## Network
**Policy Name** | **Description** | **Scope** | **Policy ID** |  **Parameters** | **Effect** | **Assignment** | **Comments** |
|------|----------------|------------|----------------|------------|----------------|--------------|-----|
| [Security Baseline for Network](https://portal.azure.com/#view/Microsoft_Azure_Policy/PolicyDetailBlade/definitionId/%2Fproviders%2FMicrosoft.Authorization%2FpolicyDefinitions%2F27960feb-a23c-4577-8d36-ef8b5f35e0be) | Security Baseline for Network | Management Group: SHB |  fix. | N/A | Deny | N/A | N/A |

# AKS Baseline Azure Policies
Built-in \'Kubernetes cluster pod security restricted standards for Linux-based workloads\' Azure Policy for Kubernetes initiative definition

* /providers/Microsoft.Authorization/policySetDefinitions/42b8ef37-b724-4e24-bbc8-7a7708edfe00

Built-in \'Kubernetes clusters should be accessible only over HTTPS\' Azure Policy for Kubernetes policy definition

* /providers/Microsoft.Authorization/policyDefinitions/1a5b4dca-0b6f-4cf5-907c-56316bc1bf3d

Built-in \'Kubernetes clusters should use internal load balancers\' Azure Policy for Kubernetes policy definition

* /providers/Microsoft.Authorization/policyDefinitions/3fc4dc25-5baf-40d8-9b05-7fe74c1bc64e

Built-in \'Kubernetes cluster services should only use allowed external IPs\' Azure Policy for Kubernetes policy definition

* /providers/Microsoft.Authorization/policyDefinitions/d46c275d-1680-448d-b2ec-e495a3b6cc89

Built-in \'[Deprecated]: Kubernetes cluster containers should only listen on allowed ports\' Azure Policy policy definition

* /providers/Microsoft.Authorization/policyDefinitions/440b515e-a580-421e-abeb-b159a61ddcbc

Built-in \'Kubernetes cluster services should listen only on allowed ports\' Azure Policy policy definition

* /providers/Microsoft.Authorization/policyDefinitions/233a2a17-77ca-4fb1-9b6b-69223d272a44

Built-in \'Kubernetes cluster pods should use specified labels\' Azure Policy policy definition

* /providers/Microsoft.Authorization/policyDefinitions/46592696-4c7b-4bf3-9e45-6c2763bdc0a6

Built-in \'Kubernetes clusters should disable automounting API credentials\' Azure Policy policy definition

* /providers/Microsoft.Authorization/policyDefinitions/423dd1ba-798e-40e4-9c4d-b6902674b423

Built-in \'Kubernetes cluster containers should run with a read only root file systemv\' Azure Policy for Kubernetes policy definition

* /providers/Microsoft.Authorization/policyDefinitions/df49d893-a74c-421d-bc95-c663042e5b80

Built-in \'Kubernetes clusters should not use the default namespace\' Azure Policy for Kubernetes policy definition

* /providers/Microsoft.Authorization/policyDefinitions/9f061a12-e40d-4183-a00e-171812443373

Built-in \'AKS container CPU and memory resource limits should not exceed the specified limits\' Azure Policy for Kubernetes policy definition

* /providers/Microsoft.Authorization/policyDefinitions/e345eecc-fa47-480f-9e88-67dcc122b164

Built-in \'AKS containers should only use allowed images\' Azure Policy for Kubernetes policy definition

* /providers/Microsoft.Authorization/policyDefinitions/febd0533-8e55-448f-b837-bd0e06f16469

Built-in \'Kubernetes cluster containers should only use allowed AppArmor profiles\' Azure Policy for Kubernetes policy definition

* /providers/Microsoft.Authorization/policyDefinitions/511f5417-5d12-434d-ab2e-816901e72a5e