#!/bin/bash

# GitHub 인증 정보
GITHUB_TOKEN=""
GITHUB_ORG="OG014110-NeOSS-OV"

# 대상 사용자
TARGET_USER="yong-jae-kim_ktdev"

# GitHub API URL
API_URL="https://api.github.com"

# 인증 헤더
AUTH_HEADER="Authorization: token $GITHUB_TOKEN"

# 조직의 모든 리포지토리 가져오기
repos=$(curl -s -H "$AUTH_HEADER" "$API_URL/orgs/$GITHUB_ORG/repos?per_page=100" | jq -r '.[].name')


delete_repo() {
  local repo=$1
  repo2=$(echo $repo)
  echo "Deleting repository: $repo2"
  curl -X DELETE \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "$API_URL/repos/$GITHUB_ORG/$repo2"
  echo "Repository $repo2 deleted."
}


# 각 리포지토리 검토 및 삭제
for repo in $repos; do

    echo "Checking repo: $repo"

    # 팀과 협업자 가져오기
    teams=$(curl -s -H "$AUTH_HEADER" "$API_URL/repos/$GITHUB_ORG/$repo/teams")
    collaborators=$(curl -s -H "$AUTH_HEADER" "$API_URL/repos/$GITHUB_ORG/$repo/collaborators")

    # 해당 리포지토리에 TARGET_USER 가 있는지 확인
    echo "$teams" | jq -e --arg user "$TARGET_USER" '.[] | select(.name | contains($user))' > /dev/null
    user_in_teams_status=$?

    echo "$collaborators" | jq -e --arg user "$TARGET_USER" '.[] | select(.login == $user)' > /dev/null
    user_in_collaborators_status=$?

    if [ $user_in_teams_status -eq 0 ] || [ $user_in_collaborators_status -eq 0 ]; then
        echo "TARGET_USER found in repo: $repo"
        delete_repo "$repo"
    else
        echo "Skipping repo: $repo (TARGET_USER not found)"
    fi
done
