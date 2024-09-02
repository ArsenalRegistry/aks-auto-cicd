resource "github_repository" "target_repo" {
  name        = var.github_repo_name

  visibility = "public"

  template {
    owner                = "ArsenalRegistry"
    repository           = "aks-template-value"
    include_all_branches = true
  }
}