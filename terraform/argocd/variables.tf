

variable "azure_resource_group_name" {
  default = "azure01"
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

variable "argo_app_name" {
  type = string
}

variable "argo_app_namespace" {
  default = "argocd"
  type = string
}

variable "dest_servser" {
  default = "https://kubernetes.default.svc"
  type = string
}

variable "dest_namespace" {
  default = "hello"
  type = string
}

variable "argocd_username" {
  default = "admin"
  type = string
}

variable "argocd_password" {
  default = "New1234!"
  type = string
}

