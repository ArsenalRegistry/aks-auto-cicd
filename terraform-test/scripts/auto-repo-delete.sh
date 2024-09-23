#!/bin/bash

# GITHUB_TOKEN="$GITHUB_TOKEN"
# GitHub organization 이름과 삭제할 리포지토리 이름을 설정합니다.
ORG_NAME="$GROUP_NAME"
REPO1="${GROUP_NAME}-ops"
REPO2="$PROJECT_NAME"
# 환경 변수에서 GitHub Personal Access Token을 가져옵니다.
GITHUB_TOKEN=$(terraform output -raw github_token)
# terraform 리소스 삭제
terraform destroy -auto-approve 




# 리포지토리 삭제 함수
delete_repo() {
  local repo=$1
  echo "Deleting repository: $repo"
  curl -X DELETE \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "$BASE_API_URL/repos/$ORG_NAME/$repo"
  echo "Repository $repo deleted."
}

# 리포지토리 삭제 호출
delete_repo "$REPO1"
delete_repo "$REPO2"
