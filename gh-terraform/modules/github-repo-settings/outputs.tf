# GitHub Repository Settings Module - Outputs

output "validated_repositories" {
  description = "Map of validated repository data (from data source)"
  value = {
    for name, repo in data.github_repository.target : name => {
      id             = repo.id
      node_id        = repo.node_id
      full_name      = repo.full_name
      description    = repo.description
      visibility     = repo.visibility
      html_url       = repo.html_url
      default_branch = repo.default_branch
    }
  }
}

output "branch_protections" {
  description = "Map of applied branch protection rules"
  value = {
    for name, bp in github_branch_protection.this : name => {
      id      = bp.id
      pattern = bp.pattern
    }
  }
}

output "rulesets" {
  description = "Map of applied repository rulesets"
  value = {
    for name, rs in github_repository_ruleset.this : name => {
      id          = rs.id
      name        = rs.name
      enforcement = rs.enforcement
    }
  }
}
