#!/bin/bash

# .env 파일을 로드하여 환경 변수 설정
export $(grep -v '^#' config.env | xargs)



if [ -f config.env ]; then
    declare -A variables  # 변수 저장을 위한 associative 배열
    error_found=false  # 오류 여부를 추적하는 플래그

    while IFS= read -r line; do
        # 주석과 빈 줄을 무시합니다.
        if [[ ! "$line" =~ ^# && ! -z "$line" ]]; then
            # TF_VAR_ 접두사 제거
            var_name=$(echo "$line" | sed -e 's/^TF_VAR_//g' | cut -d '=' -f 1)
            # 값에서 쌍따옴표 제거
            var_value=$(echo "$line" | cut -d '=' -f 2- | sed 's/^"\(.*\)"$/\1/')
            
            # 빈값 체크
            if [[ -z "$var_value" ]]; then
                echo "오류: 변수 $var_name 값이 비어 있습니다."
                error_found=true
            fi
        fi
    done < config.env

    # 빈값 오류가 있으면 스크립트 중단
    if $error_found; then
        echo "오류가 발생하여 스크립트를 중단합니다."
        # 스크립트 끝에서 대기 상태 유지
        read -p "Press any key to continue..."
        exit 1
    fi

    # 모든 변수가 올바르게 설정되었는지 확인
    echo "모든 변수가 다음과 같이 설정되었습니다:"
    for var_name in "${!variables[@]}"; do
        echo "$var_name=${variables[$var_name]}"
    done

    # 사용자 확인 (yes/no)
    read -p "이 값들이 맞습니까? (yes/no): " answer
    if [[ "$answer" != "yes" ]]; then
        echo "사용자에 의해 스크립트가 중단되었습니다."
        # 스크립트 끝에서 대기 상태 유지
        read -p "Press any key to continue..."        
        exit 1
    fi

    # 확인 후 변수들을 export
    for var_name in "${!variables[@]}"; do
        export "$var_name=${variables[$var_name]}"
    done

    echo "환경 변수가 성공적으로 설정되었습니다."
else
    echo "config.env 파일이 존재하지 않습니다."
    exit 1
fi

terraform init

terraform apply
