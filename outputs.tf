output "organization_name" {
  description = "The name of the GitHub organization"
  value       = module.github_organization.organization_name
}

output "repository_source" {
  description = "Source of repository configuration (yaml or tfvars)"
  value       = length(var.repositories) > 0 ? "tfvars" : "yaml"
}

output "repository_count" {
  description = "Total number of repositories being managed"
  value       = length(local.all_repositories)
}

output "repositories" {
  description = "Map of created repositories"
  value = {
    for name, repo in module.github_repositories : name => {
      full_name = repo.full_name
      html_url  = repo.html_url
      ssh_url   = repo.ssh_clone_url
    }
  }
}

output "copilot_seats" {
  description = "Copilot seat assignments"
  value       = module.github_copilot.seat_assignments
  sensitive   = true
}

output "devsecops_team" {
  description = "DevSecOps team information"
  value = {
    team_id   = module.devsecops_team.team_id
    team_name = module.devsecops_team.team_name
    team_slug = module.devsecops_team.team_slug
  }
}

output "repository_teams" {
  description = "Map of repository-specific teams"
  value = {
    for name, team in module.repository_teams : name => {
      team_id   = team.team_id
      team_name = team.team_name
      team_slug = team.team_slug
    }
  }
}

output "team_count" {
  description = "Total number of teams being managed"
  value       = length(local.all_teams) + 1 # +1 for devsecops team
}
