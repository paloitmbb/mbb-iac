output "repository_name" {
  description = "The name of the repository"
  value       = var.repository_name
}

output "dependabot_security_updates_enabled" {
  description = "Whether Dependabot automated security updates are enabled"
  value       = var.enable_dependabot_security_updates
}
