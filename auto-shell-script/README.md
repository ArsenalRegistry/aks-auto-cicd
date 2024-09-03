```
# 초반 세팅

# 0. AKS,ACR이 생성되어있다는 가정하에 진행.

# 1. github organization 생성

# 2. github_token 생성(계정 토큰) 

# 3. config.env 파일에 프로젝트에 맞게 변수 설정 (토큰, acr 설정값 등..)

# 4. argocd 용 네임스페이스 생성
# 4-1. argocd 생성 

# 5. argocd CLI 설치 필요 (현재 argocd.exe 파일 argocd-api 하위 경로에 위치해야함)

```

```
# 실행 순서

1. auto-template_export_import.sh 파일 실행
2. github action 실행 후 ACR 확인
3. auto-argocd-create.sh 파일 실행
4. argocd 접속 후 app 확인
```

```
# 추가 수정

# config.env 파일도 github_token & acr_password 수정 필요
```
