#!/bin/bash

# .env 파일을 로드하여 환경 변수 설정
export $(grep -v '^#' config.env | xargs)

# 환경 변수 확인 (선택 사항)
# echo "GitHub Token: $GITHUB_TOKEN"
# echo "Group Name: $GROUP_NAME"
# echo "AZURE_REGISTRY_NAME: $AZURE_REGISTRY_NAME"
# echo "za: $azure_registry_name"
