#!/bin/bash


# .env 파일을 읽어와서 환경 변수를 설정합니다.
if [ -f config.env ]; then
    while IFS= read -r line; do
        # 주석과 빈 줄을 무시합니다.
        if [[ ! "$line" =~ ^# && ! -z "$line" ]]; then
            # TF_VAR_ 접두사 제거
            var_name=$(echo "$line" | sed -e 's/^TF_VAR_//g' | cut -d '=' -f 1)
            # 값에서 쌍따옴표 제거
            var_value=$(echo "$line" | cut -d '=' -f 2- | sed 's/^"\(.*\)"$/\1/')
            
            # var_name과 var_value 확인용 출력 (디버깅용)
            # echo "var_name: $var_name, var_value: $var_value"

            # CONFIGMAP_PATTERN 변수와 다른 변수들을 처리하기 위해 조건 추가
            export "$var_name=$var_value"
        fi
    done < config.env
fi


# 0. Azure Login
echo "Logging in to Azure..."
az login
sleep 5
echo "Azure login successful."

# 0-1. Azure Cluster Connect
echo "Connect in to Azure Cluster..."
az aks get-credentials --resource-group $AZURE_RESOURCE_GROUP_NAME --name $AZURE_ClUSTER_NAME
sleep 5
kubectl get nodes
# kubectl create ns $DEST_NAMESPACE

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
