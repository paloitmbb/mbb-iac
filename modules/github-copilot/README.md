# GitHub Copilot Module

This module manages GitHub Copilot organization settings.

## Features

- Copilot organization settings
- Seat assignments for teams and users
- Content exclusions
- Policy configuration

## Important Note

The GitHub Terraform provider has limited support for Copilot features. This module provides a structure for managing Copilot settings, but you may need to use the GitHub API or CLI for full functionality.

## Usage

```hcl
module "copilot" {
  source = "./modules/github-copilot"

  organization_name       = "my-org"
  copilot_enabled         = true
  public_code_suggestions = "disabled"
  ide_chat_enabled        = true
  cli_enabled             = true
  policy_mode             = "enabled"

  seat_assignments = {
    teams = ["engineering", "platform"]
    users = ["admin@example.com"]
  }

  content_exclusions = [
    "*.env",
    "secrets/*"
  ]
}
```

## Requirements

| Name      | Version  |
| --------- | -------- |
| terraform | >= 1.6.0 |
| github    | ~> 6.0   |

## Inputs

See `variables.tf` for a complete list of available inputs.

## Outputs

| Name              | Description                  |
| ----------------- | ---------------------------- |
| organization_name | The name of the organization |
| copilot_enabled   | Whether Copilot is enabled   |
| seat_assignments  | Copilot seat assignments     |
