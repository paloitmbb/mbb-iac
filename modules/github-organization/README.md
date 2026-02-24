# GitHub Organization Module

This module manages GitHub organization settings and configurations.

## Features

- Organization settings management
- Security defaults for new repositories
- Member permissions configuration

## Usage

```hcl
module "github_organization" {
  source = "./modules/github-organization"

  organization_name                  = "my-org"
  billing_email                      = "billing@example.com"
  company                            = "My Company"
  description                        = "My GitHub Organization"
  default_repository_permission      = "read"
  members_can_create_repositories    = false
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

| Name              | Description                   |
| ----------------- | ----------------------------- |
| organization_name | The name of the organization  |
| organization_id   | The ID of the organization    |
