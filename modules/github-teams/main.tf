# Create GitHub team
resource "github_team" "this" {
  name        = var.team_name
  description = var.description
  privacy     = var.privacy

  # Parent team for hierarchical structure (optional)
  parent_team_id = var.parent_team_id
}

# Team repository access
resource "github_team_repository" "this" {
  for_each = toset(var.repositories)

  team_id    = github_team.this.id
  repository = each.value
  permission = var.permission
}
