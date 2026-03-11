# Dependabot automated security updates
resource "github_repository_dependabot_security_updates" "this" {
  count = var.enable_dependabot_security_updates ? 1 : 0

  repository = var.repository_name
  enabled    = true
}
