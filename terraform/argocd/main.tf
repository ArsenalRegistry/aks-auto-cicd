
terraform {
    required_providers {
       argocd = {
       source = "oboukili/argocd"
       version = "6.1.1"
    }
    }
  
}

data "terraform_remote_state" "vpc" {
  backend = "local"

  config = {
    path = "../cluster/terraform.tfstate"
  }
}


provider "argocd" {
  server_addr = data.terraform_remote_state.vpc.outputs.ip_addr
  username = "admin"
  password = var.argocd_admin_password
  # tls 에러 무시
  insecure = true
}


resource "argocd_application" "backend-java" {
  metadata {
    name = "backend-java"
    namespace = "argocd"
  }

  spec {
    source {
      repo_url = data.terraform_remote_state.vpc.outputs.http_clone_url
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
}