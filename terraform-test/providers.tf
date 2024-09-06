provider "azurerm" {
  features {}

  subscription_id = var.AZURE_SUBSCRIPTION
}

provider "github" {
  #owner = organization
  owner = var.GROUP_NAME
  token = var.GITHUB_TOKEN
}

provider "null" {}

provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.aks.kube_config.0.host
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
}

provider "argocd" {
  server_addr = data.kubernetes_service.argocd.status[0].load_balancer[0].ingress[0].ip
  username     = var.ARGOCD_USERNAME
  password     = var.ARGOCD_PASSWORD
  insecure     = true
}