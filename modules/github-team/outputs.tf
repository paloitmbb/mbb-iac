output "team_id" {
  description = "The ID of the created GitHub team (null if deleted)"
  value       = try(github_team.this[0].id, null)
}

output "team_slug" {
  description = "The slug of the created GitHub team (null if deleted)"
  value       = try(github_team.this[0].slug, null)
}
