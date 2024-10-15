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


# 환경 변수 기반으로 입력 값 설정
INPUTS="{\"docker_tag\": \"${DOCKER_TAG}\"}"

# 워크플로우 트리거
echo "Triggering GitHub Actions workflow..."
curl -X POST \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"ref\": \"${ACTION_BRANCH}\", \"inputs\": ${INPUTS}}" \
  "https://api.github.com/repos/${ORG_NAME}/${PROJECT_NAME}/actions/workflows/${WORKFLOW_ID}/dispatches"
  

# 워크플로우 ID를 얻기 위한 함수
get_workflow_run_id() {
  curl -H "Authorization: token ${GITHUB_TOKEN}" \
    "https://api.github.com/repos/${ORG_NAME}/${PROJECT_NAME}/actions/runs?status=in_progress" | \
    grep -o '"id": [0-9]*' | \
    awk '{print $2}' | \
    head -n 1
}

# 워크플로우 실행 상태 확인
echo "Waiting for workflow to complete..."
RUN_ID=$(get_workflow_run_id)

while [ -z "$RUN_ID" ]; do
  echo "No workflow run found. Retrying..."
  sleep 10
  RUN_ID=$(get_workflow_run_id)
done

while true; do
  RESPONSE=$(curl -H "Authorization: token ${GITHUB_TOKEN}" \
    "https://api.github.com/repos/${ORG_NAME}/${PROJECT_NAME}/actions/runs/${RUN_ID}")
  
  # STATUS와 CONCLUSION 추출 및 쌍따옴표 제거
  STATUS=$(echo "$RESPONSE" | grep -o '"status": "[^"]*"' | awk -F '": "' '{print $2}' | tr -d '"')
  CONCLUSION=$(echo "$RESPONSE" | grep -o '"conclusion": "[^"]*"' | awk -F '": "' '{print $2}' | tr -d '"')

  echo "STATUS: $STATUS"
  
  if [ "$STATUS" == "completed" ]; then
    if [ "$CONCLUSION" == "success" ]; then
      echo "Workflow completed successfully!"
      exit 0
    else
      echo "Workflow failed with conclusion: $CONCLUSION"
      exit 1
    fi
  else
    echo "Workflow in progress. Waiting..."
    sleep 10
  fi
done