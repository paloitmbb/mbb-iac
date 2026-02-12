output "team_id" {
  description = "The ID of the created team"
  value       = github_team.this.id
}

output "team_name" {
  description = "The name of the created team"
  value       = github_team.this.name
}

output "team_slug" {
  description = "The slug of the created team"
  value       = github_team.this.slug
}

output "repository_associations" {
  description = "Map of repository associations"
  value = {
    for repo in var.repositories : repo => {
      team_id    = github_team.this.id
      permission = var.permission
    }
  }
}
