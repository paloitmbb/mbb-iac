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
