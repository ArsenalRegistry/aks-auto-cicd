#!/bin/bash

# ********************************* argocd 앱 생성 쉘스크립트
# ArgoCD CLI 필요, 팀내에서 각 환경에서 진행한다면 자동화 할 필요 X
# 아래 부분은 argocd App 구성시에 로직 추가 필요
# 1. ArgoCD 로그인 argocd login 20.249.170.148 --username admin --password New1234! --insecure
# 2. API 사용을 위한 token 생성
# 여기서는 추가 작업이 필요
# toekn 생성시에 admin 계정에 access token 권한 X, cm이라는 configmap에 설정 필요
# accounts.admin: apiKey,login 권한
# accounts.admin.tokenTTL: "0s", token 기한 미설정
# kubectl rollout restart deployment argocd-server -n default # 설정 후 재시작, deployment명, namespace 명
# 위 추가작업은 아래를 사용하면 될 것 같긴한데 테스트 필요 ( 어플리케이션 확장 및 설치로 진행하면 앞에 label명은 다르지만 뒤에 리소스가 동일한 값으로 적용)
# 따라서 kubectl로 configmap에 데이터 추가 후 rollout으로 argocd server 재기동 및 token 발급까지 진행
# cm 에서 해당 설정 추가해야 ingress 부분에서 host 설정이 없어도 progress에서 멈추지 않음
# 1. 다음의 명령어를 친다.
$ kubectl -n argocd edit configmap argocd-cm
# 다음의 값을 맨 아래에 추가하여준다.
data:
  resource.customizations: |
    networking.k8s.io/Ingress:
        health.lua: |
          hs = {}
          hs.status = "Healthy"
          return hs

          
: <<'END_OF_SCRIPT'

#!/bin/bash

set -e

NAMESPACE="argocd"
CONFIGMAP_PATTERN="cm"
DATA_TO_ADD="accounts.admin: apiKey,login\naccounts.admin.tokenTTL: \"0s\"" 

# Find the ConfigMap that matches the pattern
CONFIGMAP_NAME=$(kubectl get cm -n $NAMESPACE --no-headers -o custom-columns=":metadata.name" | grep $CONFIGMAP_PATTERN | head -n 1)

if [ -z "$CONFIGMAP_NAME" ]; then
  echo "No ConfigMap found with pattern '$CONFIGMAP_PATTERN' in namespace '$NAMESPACE'"
  exit 1
fi

echo "Found ConfigMap: $CONFIGMAP_NAME"

# Get the ConfigMap data, add the new data and apply the changes
kubectl get cm $CONFIGMAP_NAME -n $NAMESPACE -o yaml | \
  sed "/data:/a\\
  $DATA_TO_ADD" | kubectl apply -f -

echo "Updated ConfigMap: $CONFIGMAP_NAME"

# Find the Deployment that includes argocd-server
DEPLOYMENT_NAME=$(kubectl get deployments -n $NAMESPACE --no-headers -o custom-columns=":metadata.name" | grep "argocd-server" | head -n 1)

if [ -z "$DEPLOYMENT_NAME" ]; then
  echo "No Deployment found with 'argocd-server' in name in namespace '$NAMESPACE'"
  exit 1
fi

echo "Found Deployment: $DEPLOYMENT_NAME"

# Restart the Deployment
kubectl rollout restart deployment $DEPLOYMENT_NAME -n $NAMESPACE

echo "Deployment $DEPLOYMENT_NAME restarted"

ACCESS_TOKEN=$(argocd account generate-token --account admin)

END_OF_SCRIPT

# : <<'END_OF_SCRIPT'

# 위 테스트 성공시에 ACCESS_TOKEN은 따로 정의해줄 필요 없음
# 그리고 token 만료 기간을 없게 설정했기 떄문에 처음 한번만 token 발행해도 될 것 같음
# 3. app 생성 api 호출
# 변수 설정
# Argocd URL
ARGOCD_SERVER="https://20.249.192.164"
# Access Token
ACCESS_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJhcmdvY2QiLCJzdWIiOiJhZG1pbjphcGlLZXkiLCJuYmYiOjE3MjQ3NDAwNzIsImlhdCI6MTcyNDc0MDA3MiwianRpIjoiMzBhMDRjYTQtOGQxMi00MjAzLTkwNTAtYzBiYTVlMmI0ZWZmIn0.LJytb0GkqMH0x_2WIvqwxQdp7eleNG1iKlQTi8tU_cI"
# App Name - backend-java-test
APP_NAME="backend-java-test"
PROJECT_NAME="demo-value-project"
# git repo url
REPO_URL="https://github.com/coe-demo-value/coe-demo-value-ops"
# gitops path
REPO_PATH="charts/demo-value-project"
# target reveision
TARGET_REVISION="HEAD"
# argocd to kubernetes cluster
DEST_SERVER="https://kubernetes.default.svc"
# Deploy Namespace
DEST_NAMESPACE="coe-demo-value"
# Argocd Namespace
ARGOCD_NAMESPACE="argocd"

# 요청 본문 작성, 추가적인 속성값은 확인해볼 필요 있음
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

# HTTP POST 요청 보내기
curl -k -X POST "${ARGOCD_SERVER}/api/v1/applications" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -d "${PAYLOAD}"


# END_OF_SCRIPT
