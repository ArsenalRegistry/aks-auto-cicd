provider "argocd" {
  server_addr = data.terraform_remote_state.vpc.outputs.ip_addr
  username = var.argocd_username
  password = var.argocd_password
  # tls 에러 무시
  insecure = true
}
