terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.0.1"
    }

    github = {
      source = "integrations/github"
      version = "~> 6.0"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.32.0"
    } 

    helm = {
      source = "hashicorp/helm"
      version = "2.15.0"
    }

   
  }
}




data "azurerm_resource_group" "azure_resource_group" {
  name = var.azure_resource_group_name
}

data "azurerm_container_registry" "example" {
  name = var.azure_registry_name
  resource_group_name = var.azure_resource_group_name
}



resource "github_actions_secret" "ACR_USERNAME" {
  repository = github_repository.target_repo.name
  secret_name = "ACR_USERNAME"
  plaintext_value = data.azurerm_container_registry.example.admin_username
}

resource "github_actions_secret" "ACR_PASSWORD" {
  repository = github_repository.target_repo.name
  secret_name = "ACR_PASSWORD"
  plaintext_value = data.azurerm_container_registry.example.admin_password
}

resource "github_actions_secret" "AZURE_URL" {
  repository = github_repository.target_repo.name
  secret_name = "AZURE_URL"
  plaintext_value = data.azurerm_container_registry.example.login_server
}

data "azurerm_kubernetes_cluster" "edu_azure_cluster" {
  name = var.azure_cluster_name
  resource_group_name = var.azure_resource_group_name
}



resource "helm_release" "argocd" {
  name = "argocd"

  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "3.35.4"

  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "configs.secret.argocdServerAdminPassword"
    value = bcrypt(var.argocd_admin_password)
  }

  set {
    name = "configs.secret.argocdServerAdminPasswordMtime"
    value = "2024-08-01T06:35:01Z"
  }
}



data "kubernetes_service" "svc" {
  metadata {
    name = "argocd-server"
    namespace = helm_release.argocd.namespace
  }
}

resource "kubernetes_namespace" "destination_namespace" {
  metadata {
    name = var.dest_namespace
  }
}


output "ip_addr" {
  value = data.kubernetes_service.svc.status[0].load_balancer[0].ingress[0].ip
}

output "http_clone_url" {
  value = github_repository.target_repo.http_clone_url
}

