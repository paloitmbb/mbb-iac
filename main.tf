# Load repositories from YAML data file
locals {
  repositories_file = "${path.module}/data/repositories.yaml"
  repositories_data = try(yamldecode(file(local.repositories_file)), { repositories = [] })

  # Normalize YAML repositories to ensure all optional attributes exist
  yaml_repositories = [
    for repo in local.repositories_data.repositories : merge(repo, {
      security          = try(repo.security, null)
      branch_protection = try(repo.branch_protection, null)
    })
  ]

  # Merge repositories from YAML file and tfvars (tfvars takes precedence if both exist)
  all_repositories = length(var.repositories) > 0 ? var.repositories : local.yaml_repositories
}

# Load teams from YAML data file
locals {
  teams_file = "${path.module}/data/teams.yaml"
  teams_data = try(yamldecode(file(local.teams_file)), { teams = [] })

  # Normalize YAML teams to ensure all optional attributes exist
  yaml_teams = [
    for team in local.teams_data.teams : merge(team, {
      description  = try(team.description, "")
      privacy      = try(team.privacy, "closed")
      maintainers  = try(team.maintainers, [])
      members      = try(team.members, [])
      repositories = try(team.repositories, [])
      deleted      = try(team.deleted, false)
    })
  ]

  # Merge teams from YAML file and tfvars (tfvars takes precedence if both exist)
  all_teams = length(var.teams) > 0 ? var.teams : local.yaml_teams
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

  # GHAS organization-level defaults (applies to new repositories)
  advanced_security_enabled_for_new_repositories               = var.ghas_config.default_enabled
  secret_scanning_enabled_for_new_repositories                 = var.ghas_config.organization_level.enable_secret_scanning
  secret_scanning_push_protection_enabled_for_new_repositories = var.ghas_config.organization_level.enable_push_protection
  dependabot_alerts_enabled_for_new_repositories               = var.ghas_config.organization_level.enable_dependabot_alerts
  dependabot_security_updates_enabled_for_new_repositories     = var.ghas_config.organization_level.enable_dependabot_security_updates
  dependency_graph_enabled_for_new_repositories                = var.ghas_config.organization_level.enable_dependency_graph
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
  archived                = try(each.value.archived, false)
  vulnerability_alerts    = try(each.value.security.enable_vulnerability_alerts, true)
  branch_protection_rules = each.value.branch_protection

  # GHAS settings managed within the repository resource
  enable_advanced_security               = try(each.value.security.enable_advanced_security, false)
  enable_secret_scanning                 = try(each.value.security.enable_secret_scanning, false)
  enable_secret_scanning_push_protection = try(each.value.security.enable_secret_scanning_push_protection, false)

  depends_on = [module.github_organization]
}

# Team Management
module "github_teams" {
  source   = "./modules/github-team"
  for_each = { for team in local.all_teams : team.name => team }

  team_name    = each.value.name
  description  = each.value.description
  privacy      = each.value.privacy
  maintainers  = each.value.maintainers
  members      = each.value.members
  repositories = each.value.repositories
  deleted      = each.value.deleted

  depends_on = [module.github_organization, module.github_repositories]
}

# Security Configuration (Dependabot security updates)
# Archived repos are excluded so that Terraform destroys their module instances
# (reverse depends_on order) BEFORE archiving the repository resource.
module "github_security" {
  source   = "./modules/github-security"
  for_each = { for repo in local.all_repositories : repo.name => repo if try(repo.security, null) != null && !try(repo.archived, false) }

  repository_name                    = each.value.name
  enable_dependabot_security_updates = try(each.value.security.enable_dependabot_security_updates, true)

  depends_on = [module.github_repositories]
}
