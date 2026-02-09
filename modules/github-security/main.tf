resource "github_repository_security_and_analysis" "this" {
  repository = var.repository_name

  advanced_security {
    status = var.enable_advanced_security ? "enabled" : "disabled"
  }

  secret_scanning {
    status = var.enable_secret_scanning ? "enabled" : "disabled"
  }

  secret_scanning_push_protection {
    status = var.enable_secret_scanning_push_protection ? "enabled" : "disabled"
  }
}
