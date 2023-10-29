#!/bin/bash

# Install Argo CD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Install Capsule
kubectl create namespace capsule-system
kubectl apply -n capsule-system -f https://raw.githubusercontent.com/clastix/capsule/master/config/install.yaml

# Wait for Argo CD and Capsule to be ready
echo "Waiting for Argo CD and Capsule components to be ready..."
kubectl wait --for=condition=Available deployment -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
kubectl wait --for=condition=Available deployment -l app=capsule -n capsule-system --timeout=300s

# Get initial Argo CD admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)

echo "Argo CD and Capsule have been installed successfully."
echo "Argo CD admin password: $ARGOCD_PASSWORD"
echo "You can access Argo CD at https://argocd.example.com (replace with your domain)"

# Delete initial Argo CD admin password
kubectl -n argocd delete secret argocd-initial-admin-secret

# Configure GitOps project in Argo CD
ARGOCD_SERVER="https://argocd.example.com"  # Replace with your Argo CD server URL
GIT_REPO="https://github.com/your-username/your-git-repo.git"  # Replace with your Git repository URL
GIT_BRANCH="main"  # Replace with your desired Git branch
APPLICATION_NAME="example-app"  # Replace with your application name

kubectl apply -n argocd -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $APPLICATION_NAME
  namespace: argocd
spec:
  destination:
    server: $ARGOCD_SERVER
    namespace: default
  project: default
  source:
    repoURL: $GIT_REPO
    targetRevision: $GIT_BRANCH
    path: /path/to/your/application/manifests  # Replace with the path to your application manifests in the Git repository
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

echo "GitOps project configuration has been added to Argo CD."
echo "Application '$APPLICATION_NAME' will be synced with the Git repository: $GIT_REPO"

## Configure SAML authentication in Argo CD - Azure AD App Registration Auth using OIDC
## https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/microsoft/#azure-ad-app-registration-auth-using-oidc