output "organization_name" {
  description = "The name of the organization"
  value       = github_organization_settings.this.name
}

output "organization_id" {
  description = "The ID of the organization"
  value       = github_organization_settings.this.id
}
