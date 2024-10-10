#!/bin/bash

# GitLab과 GitHub 토큰 설정
export GITLAB_PRIVATE_TOKEN="" # gitlab organization token 입력
export GITHUB_TOKEN="" #  본인 github token 입력

# Organization 명 설정
GITLAB_GROUP="one-view" # gitlab group name 입력
GITLAB_GROUP_ID="14974" # gitlab group id 입력
GITHUB_ORG="OG014110-NeOSS-OV" # github organization 입력
GITHUB_TEAM="one-view"  # github organization 내 추가할 새로운 팀 추가하여 입력(미리 등록해놔야함)

# GitLab에서 그룹 하위 모든 프로젝트 목록 가져오기
gitlab_api="https://gitlab.dspace.kt.co.kr/api/v4/groups/${GITLAB_GROUP_ID}/projects?per_page=100"

projects=$(curl --silent --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" "$gitlab_api" | jq -r '.[].name')
readarray -t project_list <<< "$projects"

# 각 프로젝트를 GitHub에 미러링
for project in "${project_list[@]}"; do
    # 공백 제거
    cleaned_project=$(echo "$project" | tr -d '[:space:]')
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
    # 클론 시도 및 재시도 로직 추가
    for attempt in {1..3}; do  # 최대 3회 시도
        if git clone --mirror "$gitlab_project_url"; then
            cd "$cleaned_project.git" || exit
            
            # GitHub 원격 저장소 추가
            git remote add github "$github_repo_url"
            
            # 미러링 푸시 (HTTPS 사용)
            if git push --mirror "https://${GITHUB_TOKEN}:x-oauth-basic@github.com/${GITHUB_ORG}/$cleaned_project.git"; then
                echo "Successfully pushed to GitHub for project $cleaned_project."
                break  # 푸시 성공 시 루프 종료
            else
                echo "Error: Failed to push to GitHub for project $cleaned_project."
                break  # 푸시 실패 시 루프 종료
            fi

            # 작업 완료 후 원래 디렉토리로 돌아가기
            cd .. || exit
            rm -rf "$cleaned_project.git" && echo "Cleaned up $cleaned_project.git."
            break  # 클론 성공 시 루프 종료
        else
            echo "Error: Failed to clone project $cleaned_project. Attempt $attempt of 3. Retrying..."
            sleep 5  # 잠시 대기 후 재시도
        fi
    done

    # 팀 권한을 admin으로 설정 
    team_permission_response=$(curl --silent --write-out "\n%{http_code}" --request PUT \
        "https://api.github.com/orgs/$GITHUB_ORG/teams/$GITHUB_TEAM/repos/$GITHUB_ORG/$cleaned_project" \
        --header "Authorization: token ${GITHUB_TOKEN}" \
        --header "Accept: application/vnd.github.v3+json" \
        --data '{"permission":"admin"}')

    # 응답 코드와 내용 분석
    http_code=$(echo "$team_permission_response" | tail -n1)
    response_body=$(echo "$team_permission_response" | head -n-1)

    if [[ "$http_code" == "404" ]]; then
        echo "Error: Team $GITHUB_TEAM not found or repository $cleaned_project does not exist."
    elif [[ "$http_code" == "204" ]]; then
        echo "Successfully set admin permissions for team $GITHUB_TEAM on project $cleaned_project."
    else
        echo "Unexpected error. HTTP Code: $http_code. Response: $response_body"
    fi

    echo "finish" $cleaned_project
done

echo "All projects have been migrated."
