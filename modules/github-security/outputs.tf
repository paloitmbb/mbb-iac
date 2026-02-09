output "repository_name" {
  description = "The name of the repository"
  value       = var.repository_name
}

output "advanced_security_enabled" {
  description = "Whether Advanced Security is enabled"
  value       = var.enable_advanced_security
}

output "secret_scanning_enabled" {
  description = "Whether secret scanning is enabled"
  value       = var.enable_secret_scanning
}

output "secret_scanning_push_protection_enabled" {
  description = "Whether secret scanning push protection is enabled"
  value       = var.enable_secret_scanning_push_protection
}
