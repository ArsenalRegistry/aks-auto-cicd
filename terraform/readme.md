## 실행 순서

0. azure cli 로그인 & 리소스 그룹, 레지스트리 생성
1. `variables.tf`, `main.tf` 파일 변수값 추가
2. `terraform init`
3. `main.tf` 파일에서 이하 파트를 삭제하고 `terraform apply`

```
provider "argocd" {
  server_addr = data.kubernetes_service.svc.status[0].load_balancer[0].ingress[0].ip
  username = "admin"
  password = "New1234!"
  # tls 에러 무시
  insecure = true
}


resource "argocd_application" "backend-java" {
  metadata {
    name = "backend-java"
    namespace = helm_release.argocd.namespace
  }

  spec {
    source {
      repo_url = data.github_repository.argocd_test.http_clone_url
      path = "gitops/backend-java/overlays/dev"
      target_revision = "main"
    }

    destination {
      server = "https://kubernetes.default.svc"
      namespace = var.destination_namespace
    }

    sync_policy {
      automated {
        prune = true
        self_heal = true
        allow_empty = true
      }
    }
  }

  depends_on = [ kubernetes_namespace.destination_namespace, helm_release.argocd ]
}
```

4. 위 코드를 추가하고 `terraform apply`
