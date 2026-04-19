# =============================================================================
# Shard State — Repositories filtered by state-group-<shard_id> topic
# =============================================================================
# Each shard manages a subset of repositories (up to 50) identified by the
# 'state-group-NNN' topic. Team-repo bindings for repos in this shard are
# also managed here. Team definitions (shells) live in the global state.
#
# Usage:
#   terraform init \
#     -backend-config="environments/<env>/backend.tfvars" \
#     -backend-config="key=github-shard-<NNN>.terraform.tfstate"
#   terraform plan -var="shard_id=<NNN>" \
#     -var-file="environments/<env>/terraform.tfvars"
# =============================================================================

# Load repositories from YAML data files
# Supports split YAML files for merge-conflict reduction: data/repositories.yaml,
# data/repositories-002.yaml, data/repositories-003.yaml, etc.
# All files are loaded and merged; the split is independent of state-group shards.
locals {
  repositories_dir = "${path.module}/../data"

  # Discover all repository YAML files (primary + splits)
  repositories_files = fileset(local.repositories_dir, "repositories*.yaml")

  # Load and flatten repositories from all discovered YAML files
  yaml_repositories_raw = flatten([
    for f in local.repositories_files :
    try(yamldecode(file("${local.repositories_dir}/${f}")).repositories, [])
  ])

  # Normalize YAML repositories into uniform objects
  yaml_repositories = [
    for repo in local.yaml_repositories_raw : {
      name               = repo.name
      description        = try(repo.description, "")
      visibility         = try(repo.visibility, "private")
      features           = repo.features
      default_branch     = try(repo.default_branch, "main")
      topics             = try(repo.topics, [])
      security           = try(repo.security, null)
      branch_protection  = try(repo.branch_protection, null)
      archived           = try(repo.archived, false)
      archive_on_destroy = try(repo.archive_on_destroy, false)
    }
  ]

  all_repositories = length(var.repositories) > 0 ? var.repositories : tolist(local.yaml_repositories)
}

# Load teams from YAML data file
locals {
  teams_file = "${path.module}/../data/teams.yaml"
  teams_data = try(yamldecode(file(local.teams_file)), { teams = [] })

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

  all_teams = length(var.teams) > 0 ? var.teams : tolist(local.yaml_teams)
}

# ---------------------------------------------------------------------------
# Shard filtering — only repos with topic "state-group-<shard_id>"
# ---------------------------------------------------------------------------
locals {
  shard_topic = "state-group-${var.shard_id}"

  # Filter repos belonging to this shard
  shard_repositories = [
    for repo in local.all_repositories : repo
    if contains(repo.topics, local.shard_topic)
  ]

  # Set of repo names in this shard (for team-repo binding filtering)
  shard_repo_names = toset([for r in local.shard_repositories : r.name])

  # Filter team→repo bindings to only repos in this shard.
  # Each entry is a flat { team_slug, repository, permission } object for for_each.
  shard_team_repo_bindings = {
    for binding in flatten([
      for team in local.all_teams : [
        for repo_binding in team.repositories : {
          key        = "${team.name}/${repo_binding.repository}"
          team_slug  = team.name
          repository = repo_binding.repository
          permission = repo_binding.permission
        }
        if contains(local.shard_repo_names, repo_binding.repository)
      ]
      if !try(team.deleted, false)
    ]) : binding.key => binding
  }

  # Unique team slugs referenced by bindings in this shard
  shard_team_slugs = toset([for b in values(local.shard_team_repo_bindings) : b.team_slug])
}

# ---------------------------------------------------------------------------
# Repository Management
# ---------------------------------------------------------------------------
module "github_repositories" {
  source   = "../modules/github-repository"
  for_each = { for repo in local.shard_repositories : repo.name => repo }

  repository_name         = each.value.name
  description             = each.value.description
  visibility              = each.value.visibility
  has_issues              = each.value.features.has_issues
  has_projects            = each.value.features.has_projects
  has_wiki                = each.value.features.has_wiki
  default_branch          = each.value.default_branch
  topics                  = each.value.topics
  archived                = try(each.value.archived, false)
  archive_on_destroy      = try(each.value.archive_on_destroy, false)
  vulnerability_alerts    = try(each.value.security.enable_vulnerability_alerts, true)
  branch_protection_rules = each.value.branch_protection

  # GHAS settings managed within the repository resource
  enable_advanced_security               = try(each.value.security.enable_advanced_security, false)
  enable_secret_scanning                 = try(each.value.security.enable_secret_scanning, false)
  enable_secret_scanning_push_protection = try(each.value.security.enable_secret_scanning_push_protection, false)
}

# ---------------------------------------------------------------------------
# Security Configuration (Dependabot security updates)
# ---------------------------------------------------------------------------
module "github_security" {
  source   = "../modules/github-security"
  for_each = { for repo in local.shard_repositories : repo.name => repo if try(repo.security, null) != null && !try(repo.archived, false) }

  repository_name                    = each.value.name
  enable_dependabot_security_updates = try(each.value.security.enable_dependabot_security_updates, true)

  depends_on = [module.github_repositories]
}

# ---------------------------------------------------------------------------
# Team-Repo Bindings — look up team IDs via data source, bind to repos in shard
# ---------------------------------------------------------------------------
# Look up team IDs from the GitHub API (teams are created in the global state)
data "github_team" "lookup" {
  for_each = local.shard_team_slugs
  slug     = each.value
}

resource "github_team_repository" "this" {
  for_each = local.shard_team_repo_bindings

  team_id    = data.github_team.lookup[each.value.team_slug].id
  repository = each.value.repository
  permission = each.value.permission

  depends_on = [module.github_repositories]
}
