# Development Environment Configuration

organization_name = "paloitmbb"

organization = {
  name                            = "paloitmbb"
  billing_email                   = "zang@palo-it.com"
  company                         = "Palo IT Singapore"
  description                     = "Temporary Organization for Github IaC Sandbox"
  default_repository_permission   = "read"
  members_can_create_repositories = false
}

organization_secrets   = {}
organization_variables = {}

repositories = []

ghas_config = {
  default_enabled = false
  organization_level = {
    enable_secret_scanning   = false
    enable_push_protection   = false
    enable_dependabot_alerts = true
    enable_dependency_graph  = true
  }
}

copilot_config = {
  enabled                 = false
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
