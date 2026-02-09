# Load repositories from YAML data file
locals {
  repositories_file = "${path.module}/data/repositories.yaml"
  repositories_data = fileexists(local.repositories_file) ? yamldecode(file(local.repositories_file)) : { repositories = [] }
  
  # Merge repositories from YAML file and tfvars (tfvars takes precedence if both exist)
  yaml_repositories = local.repositories_data.repositories
  all_repositories  = length(var.repositories) > 0 ? var.repositories : local.yaml_repositories
}

# Organization Management
module "github_organization" {
  source = "./modules/github-organization"

  organization_name               = var.organization.name
  billing_email                   = var.organization.billing_email
  company                         = var.organization.company
  description                     = var.organization.description
  default_repository_permission   = var.organization.default_repository_permission
  members_can_create_repositories = var.organization.members_can_create_repositories
  organization_secrets            = var.organization_secrets
  organization_variables          = var.organization_variables
}

# Repository Management
module "github_repositories" {
  source   = "./modules/github-repository"
  for_each = { for repo in local.all_repositories : repo.name => repo }

  repository_name         = each.value.name
  description             = each.value.description
  visibility              = each.value.visibility
  has_issues              = each.value.features.has_issues
  has_projects            = each.value.features.has_projects
  has_wiki                = each.value.features.has_wiki
  default_branch          = each.value.default_branch
  topics                  = each.value.topics
  branch_protection_rules = each.value.branch_protection
  teams                   = each.value.teams
  repository_secrets      = each.value.secrets
  repository_variables    = each.value.variables

  depends_on = [module.github_organization]
}

# Security Configuration
module "github_security" {
  source   = "./modules/github-security"
  for_each = { for repo in local.all_repositories : repo.name => repo if repo.security != null }

  repository_name                        = each.value.name
  enable_vulnerability_alerts            = each.value.security.enable_vulnerability_alerts
  enable_advanced_security               = each.value.security.enable_advanced_security
  enable_secret_scanning                 = each.value.security.enable_secret_scanning
  enable_secret_scanning_push_protection = each.value.security.enable_secret_scanning_push_protection
  enable_dependabot_alerts               = each.value.security.enable_dependabot_alerts
  enable_dependabot_security_updates     = each.value.security.enable_dependabot_security_updates

  depends_on = [module.github_repositories]
}

# Copilot Configuration
module "github_copilot" {
  source = "./modules/github-copilot"

  organization_name       = var.organization.name
  copilot_enabled         = var.copilot_config.enabled
  public_code_suggestions = var.copilot_config.public_code_suggestions
  ide_chat_enabled        = var.copilot_config.ide_chat_enabled
  cli_enabled             = var.copilot_config.cli_enabled
  policy_mode             = var.copilot_config.policy_mode
  seat_assignments        = var.copilot_config.seat_assignments
  content_exclusions      = var.copilot_config.content_exclusions

  depends_on = [module.github_organization]
}
