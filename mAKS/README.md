# Managed AKS (MAKS) - Managed Azure Kubernetes Service for Finance

Managed AKS (MAKS) is a robust, secure, and scalable managed service built specifically for a large finance client. It is designed as a multi-tenant cluster that supports various tenants, including onboarding processes. MAKS can seamlessly handle both development and production workloads while adhering to the AKS Regulated Baseline established by Microsoft.

## Features

- **Multi-Tenant Support:** MAKS is designed to support multiple tenants, enabling secure isolation and efficient resource utilization.
- **Regulated Baseline Compliance:** Built according to the AKS Regulated Baseline guidelines provided by Microsoft, ensuring a secure and compliant Kubernetes environment.
- **Dev and Prod Workloads:** MAKS is optimized to handle both development and production workloads, providing flexibility and scalability for diverse application requirements.

## Repository Structure

- **bicep-modules:** This folder contains Bicep modules used in the deployment of MAKS.
- **cluster-bootstrap.sh:** A shell script used for bootstrapping the MAKS cluster.
- **cluster-manifests:** Cluster manifests for bootstrapping, managed by ArgoCD.
- **docs:** Documentation folder containing additional resources and guides.
- **main-development-params.bicepparam:** Parameter file for configuring MAKS in the development environment.
- **main-production-params.bicepparam:** Parameter file for configuring MAKS in the production environment.
- **main-staging-params.bicepparam:** Parameter file for configuring MAKS in the staging environment.
- **main.bicep:** Main deployment file that utilizes parameters and modules to deploy MAKS.

## Getting Started

To get started with MAKS, follow these steps:

1. **Clone the Repository:**
   ```bash
   git clone <repository-url>
   cd maks
   ```

2. **Configure Parameters:**
   - Review and modify the appropriate parameter files (`main-development-params.bicepparam`, `main-production-params.bicepparam`, etc.) based on your environment requirements.

3. **Run Cluster Bootstrap Script:**
   ```bash
   ./cluster-bootstrap.sh
   ```
   This script will set up the MAKS cluster using the specified parameters and modules.

4. **Manage Cluster with ArgoCD:**
   - Use the cluster manifests in the `cluster-manifests` folder to manage the MAKS cluster using ArgoCD.

## Documentation

For detailed information about MAKS and its features, refer to the documentation in the [docs](docs) folder. The documentation provides in-depth guides, best practices, and troubleshooting tips to help you effectively manage your MAKS cluster.

## AKS Regulated Baseline Compliance

MAKS is built in strict adherence to the AKS Regulated Baseline guidelines provided by Microsoft. For more information about the AKS Regulated Baseline, please refer to the [official Microsoft documentation](https://docs.microsoft.com/en-us/azure/aks/regulated-workloads).

---

**Note:** MAKS is a proprietary managed service developed for a specific client in the finance sector. For inquiries or support, please contact the MAKS support team at [support@maks-finance.com](mailto:support@maks-finance.com).