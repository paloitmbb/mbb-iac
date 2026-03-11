# Development Environment Configuration

organization = {
  name                            = "paloitmbb"
  billing_email                   = "zang@palo-it.com"
  company                         = "Palo IT Singapore"
  description                     = "Temporary Organization for Github IaC Sandbox"
  default_repository_permission   = "read"
  members_can_create_repositories = false
}

repositories = []

ghas_config = {
  default_enabled = false
  organization_level = {
    enable_secret_scanning             = false
    enable_push_protection             = false
    enable_dependabot_alerts           = true
    enable_dependabot_security_updates = true
    enable_dependency_graph            = true
  }
}
