## Vilket problem löser Capsule för multi tenant cluster?
## 1. Capsule är en Kubernetes operator som möjliggör multi-tenancy i Kubernetes kluster.
## 2. Capsule-proxy är en Kubernetes operator som möjliggör att strypa k8s api för olika tenants. (ex. en tenant som kör "kubectl list namespace", kommer enbart se de namespace som ligger under den tenant som de tillhör)
## 3. RBAC läggs till på tenant nivå vilket möjliggör att tenants kan se alla tillhörande namespace till tenant.
## 4. Stöd för AAD
## 5. Stöd för Azure RBAC(?)


helm repo add capsule https://clastix.github.io/charts
helm install capsule capsule/capsule -n capsule
helm install capsule-proxy clastix/capsule-proxy -n capsule


# if to use ingress
# helm upgrade --install capsule-proxy clastix/capsule-proxy \
#    -n capsule-system \
#    --set ingress.enabled=true
#    --set ingress.hosts[0].host="capsule.yourcompany.com"
#    --set ingress.hosts[0].paths[0]="/"