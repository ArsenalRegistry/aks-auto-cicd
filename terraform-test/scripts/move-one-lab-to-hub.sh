#!/bin/bash

# GitLab과 GitHub 토큰 설정
export GITLAB_PRIVATE_TOKEN="" # gitlab organization token 입력
export GITHUB_TOKEN="" # 본인 github token 입력

# Organization 명 설정
GITLAB_GROUP="vivaldi" # gitlab group name 입력
GITHUB_ORG="BG012401-Vivaldi" # github organization 입력
# GITHUB_TEAM="one-view"  # github organization 내 추가할 새로운 팀 추가하여 입력(미리 등록해놔야함)

# GitLab에서 특정 프로젝트 ID 설정 (하나의 프로젝트만 옮기고 싶을 때 사용)
GITLAB_PROJECT_ID="12012"  # gitlab project id 입력
GITLAB_PROJECT_API="https://gitlab.dspace.kt.co.kr/api/v4/projects/${GITLAB_PROJECT_ID}"

# GitLab에서 프로젝트 정보 가져오기
project_name=$(curl --silent --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" "$GITLAB_PROJECT_API" | jq -r '.name')

# 프로젝트 명 공백 제거
cleaned_project=$(echo "$project_name" | tr -d '[:space:]')
echo "Migrating project: $cleaned_project"

# GitHub에 새로운 저장소 생성
create_repo_response=$(curl --silent --request POST "https://api.github.com/orgs/${GITHUB_ORG}/repos" \
    --header "Authorization: token ${GITHUB_TOKEN}" \
    --header "Accept: application/vnd.github.v3+json" \
    --data "{\"name\":\"$cleaned_project\", \"private\":true}")

# API 응답 확인
github_repo_url=$(echo "$create_repo_response" | jq -r '.ssh_url')
if [[ "$github_repo_url" == "null" ]]; then
    echo "Error: Repository creation failed for project $cleaned_project. Response: $create_repo_response"
    
    # 이미 존재하는 경우 GitHub 저장소 URL을 찾기
    github_repo_url="https://github.com/${GITHUB_ORG}/$cleaned_project.git"
    echo "Using existing repository: $github_repo_url"
else
    echo "Repository $cleaned_project successfully created at $github_repo_url."
fi

# GitHub 리포지토리가 생성되었는지 확인
echo "Verifying repository creation..."
for i in {1..5}; do
    repo_check_response=$(curl --silent --header "Authorization: token ${GITHUB_TOKEN}" \
        "https://api.github.com/repos/${GITHUB_ORG}/${cleaned_project}")
    if [[ $(echo "$repo_check_response" | jq -r '.id') != "null" ]]; then
        echo "Repository $cleaned_project is confirmed to exist."
        break
    else
        echo "Repository $cleaned_project not found yet, retrying in 5 seconds... ($i/5)"
        sleep 5
    fi
done

# GitLab 프로젝트 URL (HTTPS)
gitlab_project_url="https://gitlab.dspace.kt.co.kr/${GITLAB_GROUP}/$cleaned_project.git"

# GitLab 프로젝트를 GitHub으로 미러링
# 이미 클론된 프로젝트가 있는지 확인
if [ -d "$cleaned_project.git" ]; then
    echo "Directory $cleaned_project.git already exists. Using existing clone."
    cd "$cleaned_project.git" || exit
else
    # 클론 시도 및 재시도 로직 추가
    for attempt in {1..3}; do  # 최대 3회 시도
        if git clone --mirror "$gitlab_project_url"; then
            cd "$cleaned_project.git" || exit
            break  # 클론 성공 시 루프 종료
        else
            echo "Error: Failed to clone project $cleaned_project. Attempt $attempt of 3. Retrying..."
            sleep 5  # 잠시 대기 후 재시도
        fi
    done
fi

# GitHub 원격 저장소 추가 (이미 존재하는 경우 무시)
git remote add github "$github_repo_url" 2>/dev/null || echo "GitHub remote already exists."

# 미러링 푸시 (HTTPS 사용)
if git push --mirror "https://${GITHUB_TOKEN}:x-oauth-basic@github.com/${GITHUB_ORG}/$cleaned_project.git"; then
    echo "Successfully pushed to GitHub for project $cleaned_project."
else
    echo "Error: Failed to push to GitHub for project $cleaned_project."
fi

# 작업 완료 후 원래 디렉토리로 돌아가기
cd .. || exit
echo "Migration completed for project $cleaned_project."
