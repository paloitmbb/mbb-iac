# GitHub Repository Module

This module manages GitHub repository creation and configuration.

## Features

- Repository creation with customizable settings
- Branch protection rules
- Team access management
- Repository webhooks
- GitHub Pages configuration

## Usage

```hcl
module "repository" {
  source = "./modules/github-repository"

  repository_name = "my-repo"
  description     = "My repository"
  visibility      = "private"

  has_issues   = true
  has_projects = true
  has_wiki     = false

  default_branch = "main"
  topics         = ["terraform", "infrastructure"]

  branch_protection_rules = {
    pattern                         = "main"
    required_approving_review_count = 2
    require_code_owner_reviews      = true
    dismiss_stale_reviews           = true
  }

  teams = [
    {
      team       = "engineering"
      permission = "push"
    }
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

| Name            | Description                     |
| --------------- | ------------------------------- |
| repository_name | The name of the repository      |
| repository_id   | The ID of the repository        |
| full_name       | The full name of the repository |
| html_url        | The HTML URL of the repository  |
| ssh_clone_url   | The SSH clone URL               |
| http_clone_url  | The HTTP clone URL              |
