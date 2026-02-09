output "organization_name" {
  description = "The name of the organization"
  value       = github_organization_settings.this.name
}

output "organization_id" {
  description = "The ID of the organization"
  value       = github_organization_settings.this.id
}

output "organization_secrets" {
  description = "Map of organization secrets"
  value       = { for k, v in github_actions_organization_secret.secrets : k => v.secret_name }
}

output "organization_variables" {
  description = "Map of organization variables"
  value       = { for k, v in github_actions_organization_variable.variables : k => v.variable_name }
}
