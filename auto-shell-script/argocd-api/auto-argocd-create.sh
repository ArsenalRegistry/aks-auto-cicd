#!/bin/bash


# .env 파일을 읽어와서 환경 변수를 설정합니다.
if [ -f ../config.env ]; then
    export $(grep -v '^#' ../config.env | xargs)
fi


set -e

# Variables
# NAMESPACE="argocd"
# CONFIGMAP_PATTERN="argocd-cm"
# DATA_TO_ADD=$(cat <<-EOF
#   accounts.admin: apiKey,login
#   accounts.admin.tokenTTL: "0s"
#   server.sessionDuration: 24h
#   resource.customizations: |
#     networking.k8s.io/Ingress:
#       health.lua: |
#         hs = {}
#         hs.status = "Healthy"
#         return hs
# EOF
# )

# ARGOCD_SERVER="https://20.214.196.115"
# APP_NAME="backend-java-test"
# PROJECT_NAME="default"
# REPO_URL="https://github.com/coe-demo-value/coe-demo-value-ops"
# REPO_PATH="charts/demo-value-project"
# TARGET_REVISION="HEAD"
# DEST_SERVER="https://kubernetes.default.svc"
# DEST_NAMESPACE="coe-demo-value"
# ARGOCD_NAMESPACE="argocd"
# RESOURCE_GROUP="ict-coe"
# CLUSTER_NAME="ict-coe-cluster"
# USERNAME="admin"
# PASSWORD="New1234!"
# SERVER_NAME_GREP="argo-cd-server"


# 0. Azure Login
echo "Logging in to Azure..."
az login
sleep 5
echo "Azure login successful."

# 0-1. Azure Cluster Connect
echo "Connect in to Azure Cluster..."
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME
sleep 5
kubectl get nodes

# 1. Update ConfigMap
CONFIGMAP_NAME=$(kubectl get cm -n $NAMESPACE --no-headers -o custom-columns=":metadata.name" | grep $CONFIGMAP_PATTERN | head -n 1)

if [ -z "$CONFIGMAP_NAME" ]; then
  echo "No ConfigMap found with pattern '$CONFIGMAP_PATTERN' in namespace '$NAMESPACE'"
  exit 1
fi

echo "Found ConfigMap: $CONFIGMAP_NAME"
# echo "$DATA_TO_ADD"
kubectl patch cm $CONFIGMAP_NAME -n $NAMESPACE --type merge -p '{
  "data": {
    "accounts.admin": "apiKey,login",
    "accounts.admin.tokenTTL": "0s",
    "server.sessionDuration": "24h",
    "resource.customizations": "networking.k8s.io/Ingress:\n  health.lua: |\n    hs = {}\n    hs.status = \"Healthy\"\n    return hs"
  }
}'
kubectl get cm $CONFIGMAP_NAME -n $NAMESPACE -o yaml
echo "Updated ConfigMap: $CONFIGMAP_NAME"


# 2. Rollout restart the argo-cd-server deployment
DEPLOYMENT_NAME=$(kubectl get deployments -n $NAMESPACE --no-headers -o custom-columns=":metadata.name" | grep $SERVER_NAME_GREP | head -n 1)

if [ -z "$DEPLOYMENT_NAME" ]; then
  echo "No Deployment found with '$SERVER_NAME_GREP' in name in namespace '$NAMESPACE'"
  exit 1
fi

echo "Found Deployment: $DEPLOYMENT_NAME"

kubectl rollout restart deployment $DEPLOYMENT_NAME -n $NAMESPACE

echo "Restarting Deployment $DEPLOYMENT_NAME..."

# 2-1. Wait until the Deployment is ready (READY 1/1)
echo "Waiting for deployment $DEPLOYMENT_NAME to be ready..."

get_youngest_pod() {
  kubectl get pods -n $NAMESPACE --sort-by=.metadata.creationTimestamp | grep $SERVER_NAME_GREP | tail -n 1 | awk '{print $1}'
}

# Get the name of the youngest argo-cd-server pod
YOUNGEST_POD=$(get_youngest_pod)

# Wait until the youngest pod is in the READY 1/1 state
while true; do
  POD_READY_STATUS=$(kubectl get pod $YOUNGEST_POD -n $NAMESPACE -o jsonpath='{.status.containerStatuses[0].ready}')

  if [ "$POD_READY_STATUS" == "true" ]; then
    echo "Pod $YOUNGEST_POD is ready."
    break
  fi

  echo "Pod $YOUNGEST_POD is not ready yet. Waiting..."
  sleep 5  # Wait for 5 seconds before checking again
done


# 2-2. Get the external IP of the LoadBalancer service
SERVICE_NAME=$(kubectl get svc -n $NAMESPACE --no-headers -o custom-columns=":metadata.name" | grep $SERVER_NAME_GREP | head -n 1)

if [ -z "$SERVICE_NAME" ]; then
  echo "No service found with 'argo-cd-server' in name in namespace '$NAMESPACE'"
  exit 1
fi

EXTERNAL_IP=$(kubectl get svc $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$EXTERNAL_IP" ]; then
  echo "No external IP found for service '$SERVICE_NAME'"
  exit 1
fi
ARGOCD_SERVER="https://"$EXTERNAL_IP 
echo "Found External IP for service '$SERVICE_NAME': $EXTERNAL_IP"
sleep 5
# 3. Generate ArgoCD Access Token

./argocd login $EXTERNAL_IP --username $USERNAME --password $PASSWORD --insecure
# ./argocd login 20.214.196.115 --username admin --password New1234! --insecure
echo "argocd login"


ACCESS_TOKEN=$(./argocd account generate-token --account $USERNAME) 
echo "ACCESS_TOKEN": "$ACCESS_TOKEN"
echo "APP_NAME: $APP_NAME"
echo "ARGOCD_NAMESPACE: $ARGOCD_NAMESPACE"
echo "PROJECT_NAME: $PROJECT_NAME"
echo "REPO_URL: $REPO_URL"
echo "REPO_PATH: $REPO_PATH"
echo "TARGET_REVISION: $TARGET_REVISION"
echo "DEST_SERVER: $DEST_SERVER"
echo "DEST_NAMESPACE: $DEST_NAMESPACE"
sleep 5
# 4. Create Application via ArgoCD API
# JSON 데이터 생성

# JSON 데이터 생성
PAYLOAD=$(cat <<EOF
{
  "apiVersion": "argoproj.io/v1alpha1",
  "kind": "Application",
  "metadata": {
    "name": "${APP_NAME}",
    "namespace": "${ARGOCD_NAMESPACE}"
  },
  "spec": {
    "project": "${PROJECT_NAME_DEFAULT}",
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
)

# JSON 데이터 확인
echo "$PAYLOAD"
sleep 5

curl -k -X POST "${ARGOCD_SERVER}/api/v1/applications" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -d "${PAYLOAD}"

echo "ArgoCD Application ${APP_NAME} created successfully"

sleep 10