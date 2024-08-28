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

    argocd = {
      source = "oboukili/argocd"
      version = "6.1.1"
    }
  }
}


provider "azurerm" {
  features {}

  subscription_id = 
}

provider "github" {
  owner = 
  token = 
}


data "azurerm_resource_group" "azure_resource_group" {
  name = var.azure_resource_group_name
}

data "azurerm_container_registry" "example" {
  name = var.azure_registry_name
  resource_group_name = var.azure_resource_group_name
}


data "github_repository" "argocd_test" {
	name = var.github_repository
}


resource "github_actions_secret" "ACR_USERNAME" {
  repository = data.github_repository.argocd_test.name
  secret_name = "ACR_USERNAME"
  plaintext_value = data.azurerm_container_registry.example.admin_username
}

resource "github_actions_secret" "ACR_PASSWORD" {
  repository = data.github_repository.argocd_test.name
  secret_name = "ACR_PASSWORD"
  plaintext_value = data.azurerm_container_registry.example.admin_password
}

resource "github_actions_secret" "AZURE_URL" {
  repository = data.github_repository.argocd_test.name
  secret_name = "AZURE_URL"
  plaintext_value = data.azurerm_container_registry.example.login_server
}



resource "azurerm_kubernetes_cluster" "edu_azure_cluster" {
  name = var.azure_cluster_name
  location = data.azurerm_resource_group.azure_resource_group.location
  resource_group_name = data.azurerm_resource_group.azure_resource_group.name
  dns_prefix = "myCluster"

  default_node_pool {
    name = "default"
    auto_scaling_enabled = true
    min_count = 2
    max_count = 5
    vm_size = "standard_d2as_v4"
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "example" {
  principal_id = azurerm_kubernetes_cluster.edu_azure_cluster.kubelet_identity[0].object_id
  role_definition_name = "Contributor"
  scope = data.azurerm_container_registry.example.id
  skip_service_principal_aad_check = true
}

provider "helm" {
  kubernetes {
    host   = azurerm_kubernetes_cluster.edu_azure_cluster.kube_config[0].host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.edu_azure_cluster.kube_config[0].client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.edu_azure_cluster.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.edu_azure_cluster.kube_config[0].cluster_ca_certificate)
  }
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

provider "kubernetes" {
  host   = azurerm_kubernetes_cluster.edu_azure_cluster.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.edu_azure_cluster.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.edu_azure_cluster.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.edu_azure_cluster.kube_config[0].cluster_ca_certificate)
}

data "kubernetes_service" "svc" {
  metadata {
    name = "argocd-server"
    namespace = helm_release.argocd.namespace
  }
}

resource "kubernetes_namespace" "destination_namespace" {
  metadata {
    name = var.destination_namespace
  }
}

##########

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

##########