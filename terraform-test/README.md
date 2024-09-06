```
# 실행 순서

# 0. config.env 파일에서 본인 설정에 맞게 수정 (GITHUB_TOKEN부분은 upload가 안돼서 뒤에 숫자 1 붙어있음)

# 1. 터미널에서 해당 경로로 진입 
cd terraform-test

# 2. 변수 설정
source load-env.sh

# 3. terraform 실행
terraform init

terraform apply
# apply 후 yes 입력


# 추가 사항
# 진행도중 az login 으로 인한 인터넷 브라우저에 로그인 선택 창 뜨며, 아이디에 맞게 클릭
# 터미널 마지막에 뜨는 argocd_server_ip 에 접속 후 확인
```