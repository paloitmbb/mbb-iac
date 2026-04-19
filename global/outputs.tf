output "organization_name" {
  description = "The name of the GitHub organization"
  value       = module.github_organization.organization_name
}

output "organization_id" {
  description = "The ID of the GitHub organization"
  value       = module.github_organization.organization_id
}

output "team_count" {
  description = "Total number of teams being managed"
  value       = length(local.all_teams)
}

output "teams" {
  description = "Map of team slugs to team IDs"
  value = {
    for name, team in module.github_teams : name => {
      id   = team.team_id
      slug = team.team_slug
    }
  }
}
