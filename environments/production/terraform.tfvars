# Production Environment Configuration

organization_name = "your-github-org"

organization = {
  name                            = "your-github-org"
  billing_email                   = "billing@example.com"
  company                         = "Your Company"
  description                     = "Production Environment"
  default_repository_permission   = "read"
  members_can_create_repositories = false
}

organization_secrets   = {}
organization_variables = {}

repositories = []

ghas_config = {
  default_enabled = true
  organization_level = {
    enable_secret_scanning   = true
    enable_push_protection   = true
    enable_dependabot_alerts = true
    enable_dependency_graph  = true
  }
}

copilot_config = {
  enabled                 = true
  public_code_suggestions = "disabled"
  ide_chat_enabled        = true
  cli_enabled             = true
  policy_mode             = "enabled"
  seat_assignments = {
    teams = []
    users = []
  }
  content_exclusions = []
}

teams = []
