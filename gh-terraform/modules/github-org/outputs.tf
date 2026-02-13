# GitHub Enterprise Organization Module - Outputs
# Returns maps of created organization information

output "organizations" {
  description = "Map of all created organizations with their details"
  value = {
    for name, org in github_enterprise_organization.this : name => {
      id   = org.id
      name = name
    }
  }
}

output "organization_ids" {
  description = "Map of organization names to their IDs"
  value = {
    for name, org in github_enterprise_organization.this : name => org.id
  }
}

output "organization_names" {
  description = "List of all created organization names"
  value       = [for name, org in github_enterprise_organization.this : name]
}

output "teams" {
  description = "Map of team keys to their IDs"
  value = {
    for key, team in github_team.this : key => {
      id   = team.id
      name = team.name
      slug = team.slug
    }
  }
}

output "team_ids" {
  description = "Map of team keys to their IDs"
  value = {
    for key, team in github_team.this : key => team.id
  }
}
