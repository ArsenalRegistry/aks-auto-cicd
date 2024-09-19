# .env 파일을 읽어와서 환경 변수를 설정합니다.
# if [ -f config.env ]; then
#     export $(grep -v '^#' config.env | xargs)
# fi
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
            echo "var_name: $var_name, var_value: $var_value"

            # CONFIGMAP_PATTERN 변수와 다른 변수들을 처리하기 위해 조건 추가
            export "$var_name=$var_value"
        fi
    done < config.env
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
perform_sed_replacement() {
    local file="$1"
    local search_string="$2"
    local replacement_string="$3"
    local os="$4"

    if [ "$os" == "Darwin" ]; then
        # macOS에서 sed 명령어 실행
        sed -i '' "s/${search_string}/${replacement_string}/g" "$file"
    else
        # Linux 및 Windows Git Bash에서 sed 명령어 실행
        sed -i "s/${search_string}/${replacement_string}/g" "$file"
    fi
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
  
  # 운영 체제 확인
  os=$(uname)

  # Check if the source path ends with "gitops-template" or "workflow-template"
  if [[ "$source_path" == *"gitops-template" ]]; then
    # Change metadata.name in YAML files
    GENERAL_NAME="$GROUP_NAME"
    PROJECT_NAME="$PROJECT_NAME"
    for file in "$directory"/*.yaml; do
        if [ -f "$file" ]; then
            echo "Updating metadata.name in $file"

            # kustomization.yaml 파일은 건너뜁니다.
            if [[ "$file" == *"kustomization.yaml" ]]; then
                echo "Skipping $file"
                continue
            fi

            # deployment.yaml 파일의 경우
            if [[ "$file" == *"deployment.yaml" ]]; then
                echo "Processing $file"
                perform_sed_replacement "$file" '\${name}' "$GENERAL_NAME" "$os"
                perform_sed_replacement "$file" '\${project_name}' "$PROJECT_NAME" "$os"
                perform_sed_replacement "$file" '\${acr_url}' "$AZURE_URL" "$os"
            else
                # 다른 YAML 파일의 경우
                echo "Processing $file"
                perform_sed_replacement "$file" '\${name}' "$GENERAL_NAME" "$os"
                perform_sed_replacement "$file" '\${namespace}' "$NAMESPACE" "$os"
            fi
        fi
    done

  elif [[ "$source_path" == *"workflow-template" ]]; then
    echo "in workflow-template"
    # Change metadata.name in YAML files
    GENERAL_NAME="$GROUP_NAME"
    echo "workflow-template edit $file"
    # .yml 파일을 처리합니다.
    for file in "$directory"/*.yml; do
        if [ -f "$file" ]; then
            if [[ "$file" == *"docker-image.yml" ]]; then
                echo "Processing $file"
                # Replace ${github.organization.name} in docker-image.yml
                perform_sed_replacement "$file" '\${github.organization.name}' "$GENERAL_NAME" "$os"
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
