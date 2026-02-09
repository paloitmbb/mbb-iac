# Note: GitHub Copilot API resources are limited in the GitHub provider
# This module provides a structure for managing Copilot settings
# You may need to use the GitHub API directly for some operations

# Placeholder for Copilot organization settings
# The GitHub provider may not have full support for all Copilot features
# Consider using the GitHub API or CLI for advanced Copilot management

locals {
  copilot_config = {
    enabled                 = var.copilot_enabled
    public_code_suggestions = var.public_code_suggestions
    ide_chat_enabled        = var.ide_chat_enabled
    cli_enabled             = var.cli_enabled
    policy_mode             = var.policy_mode
    seat_assignments        = var.seat_assignments
    content_exclusions      = var.content_exclusions
  }
}

# Note: Actual Copilot resources may need to be managed via GitHub API
# Example using null_resource to call GitHub API:
# resource "null_resource" "copilot_settings" {
#   provisioner "local-exec" {
#     command = <<EOF
#       curl -X PATCH \
#         -H "Authorization: Bearer ${var.github_token}" \
#         -H "Accept: application/vnd.github+json" \
#         https://api.github.com/orgs/${var.organization_name}/copilot/settings \
#         -d '${jsonencode(local.copilot_config)}'
#     EOF
#   }
# }
