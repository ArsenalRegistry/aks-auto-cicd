#!/bin/bash

set -e

# Variables
NAMESPACE="argocd"
CONFIGMAP_PATTERN="argocd-cm"
DATA_TO_ADD=$(cat <<-EOF
  accounts.admin: apiKey,login
  accounts.admin.tokenTTL: "0s"
  resource.customizations: |
    networking.k8s.io/Ingress:
      health.lua: |
        hs = {}
        hs.status = "Healthy"
        return hs
EOF
)

ARGOCD_SERVER="https://20.249.192.164"
APP_NAME="backend-java-test"
PROJECT_NAME="default"
REPO_URL="https://github.com/coe-demo-value/coe-demo-value-ops"
REPO_PATH="charts/demo-value-project"
TARGET_REVISION="HEAD"
DEST_SERVER="https://kubernetes.default.svc"
DEST_NAMESPACE="coe-demo-value"
ARGOCD_NAMESPACE="argocd"
RESOURCE_GROUP="ict-coe"
CLUSTER_NAME="ict-coe-cluster"
USERNAME="admin"
PASSWORD="New1234!"

# 0. Azure Login
echo "Logging in to Azure..."
az login

echo "Azure login successful."

# 0-1. Azure Cluster Connect
echo "Connect in to Azure Cluster..."
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME

# 1. Update ConfigMap
CONFIGMAP_NAME=$(kubectl get cm -n $NAMESPACE --no-headers -o custom-columns=":metadata.name" | grep $CONFIGMAP_PATTERN | head -n 1)

if [ -z "$CONFIGMAP_NAME" ]; then
  echo "No ConfigMap found with pattern '$CONFIGMAP_PATTERN' in namespace '$NAMESPACE'"
  exit 1
fi

echo "Found ConfigMap: $CONFIGMAP_NAME"

kubectl get cm $CONFIGMAP_NAME -n $NAMESPACE -o yaml | \
  sed "/data:/a\\
  $DATA_TO_ADD" | kubectl apply -f -

echo "Updated ConfigMap: $CONFIGMAP_NAME"

# 2. Rollout restart the argocd-server deployment
DEPLOYMENT_NAME=$(kubectl get deployments -n $NAMESPACE --no-headers -o custom-columns=":metadata.name" | grep "argocd-server" | head -n 1)

if [ -z "$DEPLOYMENT_NAME" ]; then
  echo "No Deployment found with 'argocd-server' in name in namespace '$NAMESPACE'"
  exit 1
fi

echo "Found Deployment: $DEPLOYMENT_NAME"

kubectl rollout restart deployment $DEPLOYMENT_NAME -n $NAMESPACE

echo "Restarting Deployment $DEPLOYMENT_NAME..."

# 2-1. Wait until the Deployment is ready (READY 1/1)
echo "Waiting for deployment $DEPLOYMENT_NAME to be ready..."

while true; do
  READY_REPLICAS=$(kubectl get deployment $DEPLOYMENT_NAME -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')

  if [ "$READY_REPLICAS" == "1" ]; then
    echo "Deployment $DEPLOYMENT_NAME is ready."
    break
  fi

  echo "Deployment $DEPLOYMENT_NAME is not ready yet. Waiting..."
  sleep 5  # Wait for 5 seconds before checking again
done


# 2-2. Get the external IP of the LoadBalancer service
SERVICE_NAME=$(kubectl get svc -n $NAMESPACE --no-headers -o custom-columns=":metadata.name" | grep "server" | head -n 1)

if [ -z "$SERVICE_NAME" ]; then
  echo "No service found with 'server' in name in namespace '$NAMESPACE'"
  exit 1
fi

EXTERNAL_IP=$(kubectl get svc $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$EXTERNAL_IP" ]; then
  echo "No external IP found for service '$SERVICE_NAME'"
  exit 1
fi

echo "Found External IP for service '$SERVICE_NAME': $EXTERNAL_IP"

# 3. Generate ArgoCD Access Token
argocd login 20.249.170.148 --username $USERNAME --password $PASSWORD --insecure

ACCESS_TOKEN=$(argocd account generate-token --account $USERNAME)

# 4. Create Application via ArgoCD API
read -r -d '' PAYLOAD << EOF
{
  "apiVersion": "argoproj.io/v1alpha1",
  "kind": "Application",
  "metadata": {
    "name": "${APP_NAME}",
    "namespace": "${ARGOCD_NAMESPACE}"
  },
  "spec": {
    "project": "${PROJECT_NAME}",
    "source": {
      "repoURL": "${REPO_URL}",
      "path": "${REPO_PATH}",
      "targetRevision": "${TARGET_REVISION}"
    },
    "destination": {
      "server": "${DEST_SERVER}",
      "namespace": "${DEST_NAMESPACE}"
    },
    "syncPolicy": {
      "automated": {
        "prune": true,
        "selfHeal": true
      }
    }
  }
}
EOF

curl -k -X POST "${ARGOCD_SERVER}/api/v1/applications" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -d "${PAYLOAD}"

echo "ArgoCD Application ${APP_NAME} created successfully"
