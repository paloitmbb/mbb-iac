# Production Environment Configuration

organization = {
  name                            = "your-github-org"
  billing_email                   = "billing@example.com"
  company                         = "Your Company"
  description                     = "Production Environment"
  default_repository_permission   = "none"
  members_can_create_repositories = false
}

repositories = []

ghas_config = {
  default_enabled = true
  organization_level = {
    enable_secret_scanning             = true
    enable_push_protection             = true
    enable_dependabot_alerts           = true
    enable_dependabot_security_updates = true
    enable_dependency_graph            = true
  }
}

# Teams are managed via data/teams.yaml
teams = []