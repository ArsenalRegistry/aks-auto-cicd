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


ARGOCD_TOKEN=$(curl -L -X POST -H "Content-Type: application/json" -d '{"username": "'"$ARGOCD_USERNAME"'", "password": "'"$ARGOCD_PASSWORD"'"}' \
  http://$ARGOCD_HOST_SERVER/api/v1/session | jq -r '.token')

echo $ARGOCD_TOKEN

# 리포지토리 존재 여부 확인
check_response=$(curl -s -L -X GET "http://$ARGOCD_HOST_SERVER/api/v1/repositories" \
  -H "Authorization: Bearer $ARGOCD_TOKEN" \
  -H "Content-Type: application/json")

# 응답 출력 (디버깅 용도)
echo "API Response: $check_response"

# 리포지토리 리스트에서 특정 리포지토리 확인
repo_exists=$(echo "$check_response" | jq '.items[] | select(.repo == "'"${REPO_URL}.git"'")')

if [ -n "$repo_exists" ]; then
  echo "Repository already exists. Skipping..."
  exit 0
else
  echo "Repository not found. Adding new repository..."


  
  # 리포지토리 추가 요청
  response=$(curl -s -o response.json -w "%{http_code}" -L -X POST "http://$ARGOCD_HOST_SERVER/api/v1/repositories" \
    -H "Authorization: Bearer $ARGOCD_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "repo": "'"${REPO_URL}.git"'",
      "username": "'"$GITHUB_USERNAME"'",
      "password": "'"$GITHUB_TOKEN"'",
      "insecure": false,
      "project": "default"
    }')

  if [ "$response" -eq 200 ]; then
    echo "Repository added successfully."
  else
    echo "Failed to add repository. HTTP Status: $response"
    cat response.json
    exit 1
  fi
fi








