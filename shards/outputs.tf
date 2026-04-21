output "repositories_file" {
  description = "The YAML filename this shard manages"
  value       = var.repositories_file
}

output "repository_count" {
  description = "Number of repositories managed by this shard"
  value       = length(local.shard_repositories)
}

output "repositories" {
  description = "Map of repository details managed by this shard"
  value = {
    for name, repo in module.github_repositories : name => {
      full_name = repo.full_name
      html_url  = repo.html_url
      ssh_url   = repo.ssh_clone_url
    }
  }
}

output "team_repo_binding_count" {
  description = "Number of team-repo bindings managed by this shard"
  value       = length(local.shard_team_repo_bindings)
}
