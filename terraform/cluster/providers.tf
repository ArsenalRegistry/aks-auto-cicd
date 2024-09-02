provider "azurerm" {
  features {}

  subscription_id = "7ea86df1-2e18-4abf-ac54-0b241da25a7e"
}

provider "github" {
  #owner = organization
  owner = "coe-demo-value"
  token = "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1"
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