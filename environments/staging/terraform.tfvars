# Staging Environment Configuration

organization = {
  name                            = "your-github-org"
  billing_email                   = "billing@example.com"
  company                         = "Your Company"
  description                     = "Staging Environment"
  default_repository_permission   = "read"
  members_can_create_repositories = false
}

repositories = []

ghas_config = {
  default_enabled = true
  organization_level = {
    enable_secret_scanning   = true
    enable_push_protection   = false
    enable_dependabot_alerts = true
    enable_dependency_graph  = true
  }
}
