## 실행 순서

0. azure cli 로그인 & 리소스 그룹, 레지스트리 생성
1. cluster 디렉토리 이동
   1. `variables.tf`, `main.tf` 파일 변수값 추가
   2. `variables.tf` 내용 argocd에 복사(임시)
   3. `terraform init`
   4. `terraform apply`
2. argocd 디렉토리 이동
   1. `terraform init`
   2. `terraform apply`
