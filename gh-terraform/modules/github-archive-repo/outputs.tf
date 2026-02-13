# GitHub Archive Repository Module - Outputs

output "archived_repositories" {
  description = "Map of archived repositories with their details"
  value = {
    for name, req in var.archive_requests : name => {
      name             = name
      organization     = req.organization
      reason           = req.reason
      point_of_contact = req.point_of_contact
    }
  }
}

output "validated_repositories" {
  description = "Map of validated repository data before archiving (from data source)"
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
