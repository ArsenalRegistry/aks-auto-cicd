variable "argocd_admin_password" {
  default = "New1234!"
  type = string
}

variable "destination_namespace" {
  default = "hello"
  type = string
}

variable "azure_resource_group_name" {
  default = "azure01"
  type = string
}

variable "azure_cluster_name" {
  default = "edu_azure_cluster"
  type = string
}

variable "azure_registry_name" {
  default = "azureregistry0827"
  type = string
}

variable "github_repository" {
  default = "argocd-test"
  type = string
}

