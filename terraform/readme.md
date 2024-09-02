## 실행 순서

0. azure cli 로그인 & 리소스 그룹, 레지스트리 생성
1. `terraform.tfvars` 파일 변수값 추가
2. cluster 디렉토리 이동
   1. `terraform init`
   2. `terraform apply -var-file=../terraform.tfvars`
3. argocd 디렉토리 이동
   1. `terraform init`
   2. `terraform apply -var-file=../terraform.tfvars`
