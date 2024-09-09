terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.0.1"
    }
    argocd = {
       source = "oboukili/argocd"
       version = "6.1.1"
    }
  }
}
# Key Vault에서 GitHub 토큰 가져오기
data "azurerm_key_vault" "key_vault" {
  name                = var.KEY_VAULT_NAME
  resource_group_name = var.AZURE_RESOURCE_GROUP_NAME
}

data "azurerm_key_vault_secret" "github_token" {
  name         = "GITHUB-TOKEN"
  key_vault_id = data.azurerm_key_vault.key_vault.id
}

data "kubernetes_service" "argocd" {
  metadata {
    name = "${var.ARGOCD_INITIAL}-${var.SERVER_NAME_GREP}"
    namespace = var.NAMESPACE  # ArgoCD가 배포된 네임스페이스
  }
}

output "argocd_server_ip" {
  value = data.kubernetes_service.argocd.status[0].load_balancer[0].ingress[0].ip
}


resource "null_resource" "run_script" {
  provisioner "local-exec" {
    environment = {
      GITHUB_TOKEN = nonsensitive(data.azurerm_key_vault_secret.github_token.value)
    }
    command = "sh ${path.module}/auto-repo-setting.sh"
    working_dir = "${path.module}"  # 쉘 스크립트가 위치한 디렉토리
  }
}

data "azurerm_resource_group" "azure_resource_group" {
  name = var.AZURE_RESOURCE_GROUP_NAME
}

data "azurerm_container_registry" "example" {
  name = var.AZURE_REGISTRY_NAME
  resource_group_name = var.AZURE_RESOURCE_GROUP_NAME
}

resource "github_actions_secret" "ACTION_TOKEN" {
  depends_on = [null_resource.run_script]
  repository = var.PROJECT_NAME
  secret_name = "ACTION_TOKEN"
  # plaintext_value = var.GITHUB_TOKEN
  plaintext_value = data.azurerm_key_vault_secret.github_token.value
}
resource "github_actions_secret" "ACR_USERNAME" {
  depends_on = [null_resource.run_script]
  repository = var.PROJECT_NAME
  secret_name = "ACR_USERNAME"
  plaintext_value = data.azurerm_container_registry.example.admin_username
}

resource "github_actions_secret" "ACR_PASSWORD" {
  depends_on = [null_resource.run_script]
  repository = var.PROJECT_NAME
  secret_name = "ACR_PASSWORD"
  plaintext_value = data.azurerm_container_registry.example.admin_password
}

resource "github_actions_secret" "AZURE_URL" {
  depends_on = [null_resource.run_script]
  repository = var.PROJECT_NAME
  secret_name = "AZURE_URL"
  plaintext_value = data.azurerm_container_registry.example.login_server
}

# # github action

resource "null_resource" "github_actions_script" {
  depends_on = [github_actions_secret.AZURE_URL]
  provisioner "local-exec" {
    environment = {
      GITHUB_TOKEN = nonsensitive(data.azurerm_key_vault_secret.github_token.value)
    }
    command = "sh ${path.module}/auto-action-running.sh"
    working_dir = "${path.module}"  # 쉘 스크립트가 위치한 디렉토리
  }
}


# argocd
data "azurerm_kubernetes_cluster" "aks" {
  name                = var.AZURE_ClUSTER_NAME
  resource_group_name = var.AZURE_RESOURCE_GROUP_NAME
}



resource "null_resource" "run_argocd_script" {
  depends_on = [null_resource.github_actions_script]
  provisioner "local-exec" {
    command = "sh ${path.module}/auto-argocd-setting.sh"
    working_dir = "${path.module}"  # 쉘 스크립트가 위치한 디렉토리
  }
}


resource "argocd_application" "backend-app" {
  depends_on = [null_resource.run_argocd_script]
  metadata {
    name      = var.APP_NAME
    namespace = var.NAMESPACE
  }
  spec {

    project = var.PROJECT_NAME_DEFAULT
    
    source {
      repo_url        = var.REPO_URL
      # repo_url        = data.terraform_remote_state.vpc.outputs.http_clone_url
      path            = var.REPO_PATH
      target_revision = var.TARGET_REVISION
    }

    destination {
      server    = var.DEST_SERVER
      namespace = var.DEST_NAMESPACE
    }

    sync_policy {
      automated {
        prune     = true
        self_heal = true
        allow_empty = true
      }
    }
  }
}