
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




resource "argocd_application" "backend_app" {
  metadata {
    name = var.argo_app_name
    namespace = var.argo_app_namespace
  }

  spec {
    source {
      repo_url = data.terraform_remote_state.vpc.outputs.http_clone_url
      path = "gitops/backend-java/overlays/dev"
      target_revision = "main"
    }

    destination {
      server = var.dest_servser
      namespace = var.dest_namespace
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