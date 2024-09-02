variable "argocd_admin_password" {
  default = "New1234!"
  type = string
}

variable "destination_namespace" {
  default = "hello"
  type = string
}

variable "azure_resource_group_name" {
  type = string
}

variable "azure_cluster_name" {
  type = string
}

variable "azure_registry_name" {
  type = string
}

variable "github_repo_name" {
  type = string
}

variable "github_org" {
  type = string
}
