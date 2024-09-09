# variable "GITHUB_TOKEN" {
#   description = "GitHub Personal Access Token"
#   type        = string
# }
variable "KEY_VAULT_NAME" {
  description = "The KEY_VAULT name for your azure"
  type        = string
}

variable "GROUP_NAME" {
  description = "The group name for your repositories"
  type        = string
}

variable "PROJECT_NAME" {
  description = "The project name for your repositories"
  type        = string
}

variable "AZURE_RESOURCE_GROUP_NAME" {
  type = string
}
variable "AZURE_REGISTRY_NAME" {
  type = string
}
variable "AZURE_SUBSCRIPTION" {
  type = string
}


variable "AZURE_URL" {
  type = string
}
variable "SOURCE_REPO_URL" {
  type = string
}
variable "TARGET_ORG" {
  type = string
}
variable "BASE_API_URL" {
  type = string
}



variable "WORKFLOW_ID" {
  type = string
  description = "The ID or filename of the workflow to trigger"
}
variable "DOCKER_TAG" {
  type = string
  description = "The ID or filename of the workflow to trigger"
}
variable "ACTION_BRANCH" {
  type = string
  description = "The ID or filename of the workflow to trigger"
}


# argocd 변수

variable "AZURE_ClUSTER_NAME" {
  type = string
}
variable "CONFIGMAP_PATTERN" {
  default = "argocd-cm"
  type = string
}
variable "NAMESPACE" {
  default = "argocd"
  type = string
}
variable "SERVER_NAME_GREP" {
  type = string
}
variable "ARGOCD_INITAL" {
  type = string
}
variable "ARGOCD_USERNAME" {
  default = "admin"
  type = string
}

variable "ARGOCD_PASSWORD" {
  default = "New1234!"
  type = string
}


variable "APP_NAME" {
  type = string
}

variable "DEST_SERVER" {
  default = "https://kubernetes.default.svc"
  type = string
}

variable "DEST_NAMESPACE" {
  default = "coe-demo-value"
  type = string
}

variable "PROJECT_NAME_DEFAULT" {
  type = string
}

variable "REPO_PATH" {
  type = string
}
variable "TARGET_REVISION" {
  type = string
}
variable "REPO_URL" {
  type = string
}
