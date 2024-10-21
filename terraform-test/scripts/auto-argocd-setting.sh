#!/bin/bash

# config.env 파일에서 환경 변수 로드
if [ -f config.env ]; then
    while IFS= read -r line; do
        # 주석과 빈 줄을 무시합니다.
        if [[ ! "$line" =~ ^# && ! -z "$line" ]]; then
            # TF_VAR_ 접두사 제거
            var_name=$(echo "$line" | sed -e 's/^TF_VAR_//g' | cut -d '=' -f 1)
            # 값에서 쌍따옴표 제거
            var_value=$(echo "$line" | cut -d '=' -f 2- | sed 's/^"\(.*\)"$/\1/')
            
            # 변수 확인용 출력 (디버깅용)
            # echo "var_name: $var_name, var_value: $var_value"

            # 환경 변수로 설정
            export "$var_name=$var_value"
        fi
    done < config.env
fi

# ArgoCD 토큰이 null이면 새로 발급
if [ "$ARGOCD_TOKEN" = "null" ]; then
  echo "Token is null, generating new ArgoCD token..."
  NEW_TOKEN=$(curl -X POST -H "Content-Type: application/json" -d '{"username": "'"$ARGOCD_USERNAME"'", "password": "'"$ARGOCD_PASSWORD"'"}' \
    http://$ARGOCD_HOST_SERVER/api/v1/session | jq -r '.token')

  # config.env 파일 업데이트
  sed -i.bak 's/TF_VAR_ARGOCD_TOKEN="null"/TF_VAR_ARGOCD_TOKEN="'"$NEW_TOKEN"'" # argocd token(처음엔 null 값)/' config.env

  # 새 토큰을 환경 변수로 설정
  export ARGOCD_TOKEN=$NEW_TOKEN
fi

# ArgoCD에 리포지토리 등록
curl -X POST \
  http://$ARGOCD_HOST_SERVER/api/v1/repositories \
  -H "Authorization: Bearer $ARGOCD_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "repo": "'"${REPO_URL}.git"'",
    "username": "'"$GITHUB_USERNAME"'",
    "password": "'"$GITHUB_TOKEN"'",
    "insecure": false,
    "project": "default"
  }'
