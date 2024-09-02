provider "azurerm" {
  features {}

  subscription_id = var.azure_subscription
}

provider "github" {
  #owner = organization
  owner = var.github_org
  token = var.github_token
}

provider "helm" {
  kubernetes {
    host   = data.azurerm_kubernetes_cluster.edu_azure_cluster.kube_config[0].host
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.edu_azure_cluster.kube_config[0].client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.edu_azure_cluster.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.edu_azure_cluster.kube_config[0].cluster_ca_certificate)
  }
}

provider "kubernetes" {
  host   = data.azurerm_kubernetes_cluster.edu_azure_cluster.kube_config[0].host
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.edu_azure_cluster.kube_config[0].client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.edu_azure_cluster.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.edu_azure_cluster.kube_config[0].cluster_ca_certificate)
}