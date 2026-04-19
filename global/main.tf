# =============================================================================
# Global State — Organization settings + Team definitions (no repo bindings)
# =============================================================================
# This root config manages org-level settings and team shells.
# Team-to-repository bindings are managed in each shard (shards/).
# State key: github-global.terraform.tfstate
# =============================================================================

# Load teams from YAML data file
locals {
  teams_file = "${path.module}/../data/teams.yaml"
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

  # Merge teams from YAML file and tfvars (tfvars takes precedence if both exist).
  all_teams = length(var.teams) > 0 ? var.teams : tolist(local.yaml_teams)
}

# Organization Management
module "github_organization" {
  source = "../modules/github-organization"

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

# Team Management — team shells only (no github_team_repository bindings)
# Repo bindings are managed in each shard to avoid cross-state dependencies.
module "github_teams" {
  source   = "../modules/github-team"
  for_each = { for team in local.all_teams : team.name => team }

  team_name   = each.value.name
  description = each.value.description
  privacy     = each.value.privacy
  maintainers = each.value.maintainers
  members     = each.value.members
  deleted     = each.value.deleted

  # Pass empty repositories — repo bindings are in each shard
  repositories = []

  depends_on = [module.github_organization]
}
