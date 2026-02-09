output "organization_name" {
  description = "The name of the organization"
  value       = var.organization_name
}

output "copilot_enabled" {
  description = "Whether Copilot is enabled"
  value       = var.copilot_enabled
}

output "seat_assignments" {
  description = "Copilot seat assignments"
  value       = var.seat_assignments
  sensitive   = true
}

output "content_exclusions" {
  description = "Content exclusions for Copilot"
  value       = var.content_exclusions
}
