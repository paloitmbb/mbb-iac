# GitHub Repository Module - Outputs
# Returns maps of created repository information

output "repositories" {
  description = "Map of all created repositories with their details"
  value = {
    for name, repo in github_repository.this : name => {
      id             = repo.id
      node_id        = repo.node_id
      name           = repo.name
      full_name      = repo.full_name
      html_url       = repo.html_url
      ssh_clone_url  = repo.ssh_clone_url
      http_clone_url = repo.http_clone_url
      git_clone_url  = repo.git_clone_url
      visibility     = repo.visibility
    }
  }
}

output "repository_ids" {
  description = "Map of repository names to their IDs"
  value = {
    for name, repo in github_repository.this : name => repo.id
  }
}

output "repository_node_ids" {
  description = "Map of repository names to their Node IDs (for GraphQL)"
  value = {
    for name, repo in github_repository.this : name => repo.node_id
  }
}

output "repository_names" {
  description = "List of all created repository names"
  value       = [for name, repo in github_repository.this : repo.name]
}

output "repository_urls" {
  description = "Map of repository names to their HTML URLs"
  value = {
    for name, repo in github_repository.this : name => repo.html_url
  }
}

output "ssh_clone_urls" {
  description = "Map of repository names to their SSH clone URLs"
  value = {
    for name, repo in github_repository.this : name => repo.ssh_clone_url
  }
}

output "http_clone_urls" {
  description = "Map of repository names to their HTTPS clone URLs"
  value = {
    for name, repo in github_repository.this : name => repo.http_clone_url
  }
}

output "branch_protection_enabled" {
  description = "Map of repository names that have branch protection enabled"
  value = {
    for name, protection in github_branch_protection.main : name => true
  }
}

output "rulesets_enabled" {
  description = "Map of repository names that have rulesets enabled"
  value = {
    for name, ruleset in github_repository_ruleset.this : name => ruleset.name
  }
}
