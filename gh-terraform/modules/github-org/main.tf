# GitHub Enterprise Organization Module
# Creates and configures GitHub Enterprise Cloud organizations
# Uses for_each internally to create multiple organizations from a map

#--------------------------------------------------------------
# GitHub Enterprise Organizations
#--------------------------------------------------------------
resource "github_enterprise_organization" "this" {
  for_each = var.organizations

  enterprise_id = var.enterprise_slug
  name          = each.key
  display_name  = each.value.display_name
  description   = each.value.description
  billing_email = each.value.billing_email
  admin_logins  = each.value.admin_logins

  lifecycle {
    prevent_destroy = false
  }
}

#--------------------------------------------------------------
# Organization Settings
#--------------------------------------------------------------
resource "github_organization_settings" "this" {
  for_each = {
    for name, org in var.organizations : name => org
    if org.manage_settings
  }

  billing_email = each.value.billing_email
  name          = each.value.display_name
  description   = each.value.description
  company       = each.value.company
  blog          = each.value.blog
  email         = each.value.email
  location      = each.value.location

  # Repository defaults
  has_organization_projects                = each.value.has_organization_projects
  has_repository_projects                  = each.value.has_repository_projects
  default_repository_permission            = each.value.default_repository_permission
  members_can_create_repositories          = each.value.members_can_create_repositories
  members_can_create_public_repositories   = each.value.members_can_create_public_repositories
  members_can_create_private_repositories  = each.value.members_can_create_private_repositories
  members_can_create_internal_repositories = each.value.members_can_create_internal_repositories
  members_can_fork_private_repositories    = each.value.members_can_fork_private_repositories

  # Security
  web_commit_signoff_required                                  = each.value.web_commit_signoff_required
  advanced_security_enabled_for_new_repositories               = each.value.advanced_security_enabled_for_new_repositories
  secret_scanning_enabled_for_new_repositories                 = each.value.secret_scanning_enabled_for_new_repositories
  secret_scanning_push_protection_enabled_for_new_repositories = each.value.secret_scanning_push_protection_enabled_for_new_repositories
  dependabot_alerts_enabled_for_new_repositories               = each.value.dependabot_alerts_enabled_for_new_repositories
  dependabot_security_updates_enabled_for_new_repositories     = each.value.dependabot_security_updates_enabled_for_new_repositories
  dependency_graph_enabled_for_new_repositories                = each.value.dependency_graph_enabled_for_new_repositories

  depends_on = [github_enterprise_organization.this]
}

#--------------------------------------------------------------
# Organization Teams
#--------------------------------------------------------------
locals {
  # Flatten teams for all organizations
  org_teams = flatten([
    for org_name, org in var.organizations : [
      for team_name, team in org.teams : {
        org_name    = org_name
        team_name   = team_name
        description = team.description
        privacy     = team.privacy
        parent_id   = team.parent_id
      }
    ]
  ])
}

resource "github_team" "this" {
  for_each = {
    for item in local.org_teams :
    "${item.org_name}-${item.team_name}" => item
  }

  name        = each.value.team_name
  description = each.value.description
  privacy     = each.value.privacy

  depends_on = [github_enterprise_organization.this]
}

#--------------------------------------------------------------
# Organization Team Members
#--------------------------------------------------------------
locals {
  # Flatten team memberships
  team_members = flatten([
    for org_name, org in var.organizations : [
      for team_name, team in org.teams : [
        for member in team.members : {
          org_name  = org_name
          team_name = team_name
          username  = member.username
          role      = member.role
        }
      ]
    ]
  ])
}

resource "github_team_membership" "this" {
  for_each = {
    for item in local.team_members :
    "${item.org_name}-${item.team_name}-${item.username}" => item
  }

  team_id  = github_team.this["${each.value.org_name}-${each.value.team_name}"].id
  username = each.value.username
  role     = each.value.role

  depends_on = [github_team.this]
}

#--------------------------------------------------------------
# Organization Membership (Invite Members)
#--------------------------------------------------------------
locals {
  # Flatten org memberships
  org_members = flatten([
    for org_name, org in var.organizations : [
      for member in org.members : {
        org_name = org_name
        username = member.username
        role     = member.role
      }
    ]
  ])
}

resource "github_membership" "this" {
  for_each = {
    for item in local.org_members :
    "${item.org_name}-${item.username}" => item
  }

  username = each.value.username
  role     = each.value.role

  depends_on = [github_enterprise_organization.this]
}
