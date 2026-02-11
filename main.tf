# Load repositories from YAML data file
locals {
  repositories_file = "${path.module}/data/repositories.yaml"
  repositories_data = fileexists(local.repositories_file) ? yamldecode(file(local.repositories_file)) : { repositories = [] }

  # Normalize YAML repositories to ensure all optional attributes exist
  yaml_repositories = [
    for repo in local.repositories_data.repositories : merge(repo, {
      secrets           = try(repo.secrets, null)
      variables         = try(repo.variables, null)
      security          = try(repo.security, null)
      branch_protection = try(repo.branch_protection, null)
      teams             = try(repo.teams, null)
    })
  ]

  # Merge repositories from YAML file and tfvars (tfvars takes precedence if both exist)
  all_repositories = length(var.repositories) > 0 ? var.repositories : local.yaml_repositories
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
  repository_secrets      = try(each.value.secrets, {})
  repository_variables    = try(each.value.variables, {})

  # Security settings
  enable_advanced_security               = try(each.value.security.enable_advanced_security, false)
  enable_secret_scanning                 = try(each.value.security.enable_secret_scanning, false)
  enable_secret_scanning_push_protection = try(each.value.security.enable_secret_scanning_push_protection, false)

  depends_on = [module.github_organization]
}

# ============================================================================
# Team Management
# ============================================================================

# Load teams configuration
locals {
  teams_file = "${path.module}/data/teams.yaml"
  teams_data = fileexists(local.teams_file) ? yamldecode(file(local.teams_file)) : { teams = [] }

  # Normalize teams data
  all_teams = try(local.teams_data.teams, [])
}

# Create DevSecOps team with admin access to all repositories
module "devsecops_team" {
  source = "./modules/github-teams"

  team_name   = "paloitmbb-devsecops"
  description = "DevSecOps team with organization-level permissions to view and approve all repositories and pipelines"
  privacy     = "closed"

  # Grant admin access to all managed repositories
  repositories = [for repo in local.all_repositories : repo.name]
  permission   = "admin"

  depends_on = [module.github_repositories]
}

# Create repository-specific teams
module "repository_teams" {
  source   = "./modules/github-teams"
  for_each = { for team in local.all_teams : team.name => team }

  team_name    = each.value.name
  description  = each.value.description
  privacy      = try(each.value.privacy, "closed")
  repositories = [each.value.repository]
  permission   = each.value.permission

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
