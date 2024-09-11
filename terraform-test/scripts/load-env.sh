#!/bin/bash

# .env 파일을 로드하여 환경 변수 설정
export $(grep -v '^#' config.env | xargs)

# 임시 파일 생성
temp_file=$(mktemp)

if [ -f config.env ]; then
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

            # 변수와 값 저장 (디버깅용 출력 및 임시 파일에 기록)
            echo "var_name: $var_name, var_value: $var_value"
            echo "export $var_name=\"$var_value\"" >> "$temp_file"
        fi
    done < config.env

    # 빈값 오류가 있으면 스크립트 중단
    if $error_found; then
        echo "오류가 발생하여 스크립트를 중단합니다."
        # 스크립트 끝에서 대기 상태 유지 (터미널 종료 방지)
        read -p "Press any key to continue..."        
        rm -f "$temp_file"  # 임시 파일 삭제
        exit 1
    fi

    # 모든 변수가 올바르게 설정되었는지 확인
    echo "모든 변수가 다음과 같이 설정되었습니다:"
    grep -v '^#' config.env

    # # 사용자 확인 (yes/no)
    read "answer?이 값들이 맞습니까? (yes/no): "
    if [[ "$answer" != "yes" ]]; then
        echo "사용자에 의해 스크립트가 중단되었습니다."
        # 스크립트 끝에서 대기 상태 유지 (터미널 종료 방지)
        read "?Press any key to continue..."        
        rm -f "$temp_file"  # 임시 파일 삭제
        exit 1
    fi

    # 확인 후 임시 파일에서 변수를 export
    source "$temp_file"
    rm -f "$temp_file"  # 임시 파일 삭제

    echo "환경 변수가 성공적으로 설정되었습니다."
else
    echo "config.env 파일이 존재하지 않습니다."
    # 스크립트 끝에서 대기 상태 유지 (터미널 종료 방지)
    read -p "Press any key to continue..."
    rm -f "$temp_file"  # 임시 파일 삭제
    exit 1
fi

terraform init
terraform apply
