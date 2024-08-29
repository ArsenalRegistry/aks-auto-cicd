# .env 파일을 읽어와서 환경 변수를 설정합니다.
if [ -f config.env ]; then
    export $(grep -v '^#' config.env | xargs)
fi

# 현재 로컬 기준으로 clone 받아서 디렉토리 구조 생성해서 organization에 import하는 방식
# 추가적으로 변수값 핸들링 변수값 변경 작업 필요

# 레포지토리 존재 여부 체크 함수
repository_exists() {
  local repo_name=$1
  response=$(curl -k -s -w "%{http_code}" -H "Authorization: token $GITHUB_TOKEN" "$BASE_API_URL/repos/$TARGET_ORG/$repo_name")
  http_code=$(echo "$response" | tail -c 4)
  if [ "$http_code" -eq 200 ]; then
    return 0  # Repository exists
  else
    return 1  # Repository does not exist
  fi
}

# 레포지토리 생성 함수
create_repository() {
  local repo_name=$1
  response=$(curl -k -s -w "\n%{http_code}" -H "Authorization: token $GITHUB_TOKEN" -d '{"name":"'"$repo_name"'"}' "$BASE_API_URL/orgs/$TARGET_ORG/repos")
  http_code=$(echo "$response" | tail -n1)
  response_body=$(echo "$response" | head -n -1)
  
  if [ "$http_code" -ne 201 ]; then
    echo "Failed to create repository $repo_name"
    echo "HTTP Code: $http_code"
    echo "Response: $response_body"
    return 1
  fi
  return 0
}

# 디렉토리 생성 및 import 함수
create_directory_and_commit() {
  local repo_name=$1
  local directory=$2
  local source_path=$3
  echo "in create_directory_and_commit"
  git clone "https://${GITHUB_TOKEN}@github.com/${TARGET_ORG}/${repo_name}.git"
  if [ $? -ne 0 ]; then
    echo "Failed to clone repository $repo_name"
    sleep 10s
    return 1
  fi
  cd "$repo_name" || return 1
  
  # Check out main branch, create it if it doesn't exist
  if git rev-parse --verify main >/dev/null 2>&1; then
    git checkout main
  else
    git checkout -b main
  fi

  mkdir -p "$directory"
  if [ -d "../$source_path" ]; then
    cp -r ../"$source_path"/* "$directory"
  else
    echo "Source path ../$source_path does not exist"
    cd ..
    sleep 10s
    return 1
  fi
  
  # Check if the source path ends with "gitops-template" or "workflow-template"
  if [[ "$source_path" == *"gitops-template" ]]; then
    # Change metadata.name in YAML files
    GENERAL_NAME="$GROUP_NAME"
    PROJECT_NAME="$PROJECT_NAME"
    for file in "$directory"/*.yaml; do
      if [ -f "$file" ]; then
        echo "Updating metadata.name in $file"
        # Skip kustomization.yaml
        if [[ "$file" == *"kustomization.yaml" ]]; then
          echo "Skipping $file"
          continue
        fi
        if [[ "$file" == *"deployment.yaml" ]]; then
          # Replace ${name} and ${acr_url} in deployment.yaml
          sed -i "s/\${name}/${GENERAL_NAME}/g" "$file"
          sed -i "s/\${project_name}/${PROJECT_NAME}/g" "$file"
          sed -i "s/\${acr_url}/${AZURE_URL}/g" "$file"
        else
          # Replace ${name} in other YAML files
          sed -i "s/\${name}/${GENERAL_NAME}/g" "$file"
        fi
      fi
    done

  elif [[ "$source_path" == *"workflow-template" ]]; then
    echo "in workflow-template"
    # Change metadata.name in YAML files
    GENERAL_NAME="$GROUP_NAME"
    echo "workflow-template edit $file"
    for file in "$directory"/*.yml; do
      if [ -f "$file" ]; then
        if [[ "$file" == *"docker-image.yml" ]]; then
          # Replace ${name} and ${acr_url} in docker-image.yml
          sed -i "s/\${github.organization.name}/${GENERAL_NAME}/g" "$file"
        fi
      fi
    done
  fi


  git add .
  git commit -m "Add initial project structure"
  git push origin main
  cd ..
  rm -rf "$repo_name"
  return 0
}


# 임시 디렉토리 클론
TEMP_DIR="temp-repo"
if [ -d "$TEMP_DIR" ]; then
  rm -rf "$TEMP_DIR"
fi
git clone "$SOURCE_REPO_URL" "$TEMP_DIR"
if [ $? -ne 0 ]; then
  echo "Failed to clone the source repository"
  exit 1
fi

# Step 1: Group명-ops 레포지토리 생성
GROUP_REPO_NAME="${GROUP_NAME}-ops"
if repository_exists "$GROUP_REPO_NAME"; then
  echo "Repository $GROUP_REPO_NAME already exists. Stopping script."
  rm -rf "$TEMP_DIR"
  exit 1
else
  create_repository "$GROUP_REPO_NAME"
  if [ $? -ne 0 ]; then
    echo "Failed to create $GROUP_REPO_NAME repository. Exiting script."
    rm -rf "$TEMP_DIR"
    exit 1
  fi
fi

# Step 2: Group-ops에 charts 디렉토리 구성 및 argocd target resouce yaml 구성
CHARTS_DIRECTORY="charts/$PROJECT_NAME"
SOURCE_CHARTS_PATH="$TEMP_DIR/java-template/gitops-template"
if ! create_directory_and_commit "$GROUP_REPO_NAME" "$CHARTS_DIRECTORY" "$SOURCE_CHARTS_PATH"; then
  echo "Failed to copy files from $SOURCE_CHARTS_PATH"
  rm -rf "$TEMP_DIR"
  exit 1
fi

# Step 3: Project명-Repository 구성
if repository_exists "$PROJECT_NAME"; then
  echo "Repository $PROJECT_NAME already exists. Stopping script."
  rm -rf "$TEMP_DIR"
  exit 1
else
  create_repository "$PROJECT_NAME"
  if [ $? -ne 0 ]; then
    echo "Failed to create $PROJECT_NAME repository. Exiting script."
    rm -rf "$TEMP_DIR"
    exit 1
  fi
fi
echo "step4"
# Step 4: Project Repository에 workflow template import
WORKFLOW_DIRECTORY=".github/workflows"
SOURCE_WORKFLOW_PATH="$TEMP_DIR/java-template/workflow-template"
if ! create_directory_and_commit "$PROJECT_NAME" "$WORKFLOW_DIRECTORY" "$SOURCE_WORKFLOW_PATH"; then
  echo "Failed to copy files from $SOURCE_WORKFLOW_PATH"
  rm -rf "$TEMP_DIR"
  exit 1
fi
echo "step5"
# Step 5: Project Repository에 src template import
SOURCE_SRC_PATH="$TEMP_DIR/java-template/src-template"
if ! create_directory_and_commit "$PROJECT_NAME" "." "$SOURCE_SRC_PATH"; then
  echo "Failed to copy files from $SOURCE_SRC_PATH"
  rm -rf "$TEMP_DIR"
  exit 1
fi


# 임시 디렉토리 제거
rm -rf "$TEMP_DIR"

echo "All tasks completed successfully."

# 필요한 패키지 설치
pip install pynacl requests
pip install python-dotenv
# create_secret.py 스크립트 실행
python ./create_secret.py
if [ $? -ne 0 ]; then
  echo "Failed to execute create_secret.py"
  exit 1
fi

echo "create_secret.py executed successfully."
