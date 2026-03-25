resource "github_team" "this" {
  count       = var.deleted ? 0 : 1
  name        = var.team_name
  description = var.description
  privacy     = var.privacy
}

resource "github_team_membership" "maintainers" {
  for_each = var.deleted ? toset([]) : toset(var.maintainers)
  team_id  = github_team.this[0].id
  username = each.value
  role     = "maintainer"
}

resource "github_team_membership" "members" {
  for_each = var.deleted ? toset([]) : toset(var.members)
  team_id  = github_team.this[0].id
  username = each.value
  role     = "member"
}

# Repository access for the team
resource "github_team_repository" "this" {
  for_each   = var.deleted ? {} : { for repo in var.repositories : repo.repository => repo }
  repository = each.value.repository
  team_id    = github_team.this[0].id
  permission = each.value.permission
}
