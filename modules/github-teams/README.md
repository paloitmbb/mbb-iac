# GitHub Teams Module

Manages GitHub teams and their repository access permissions.

## Features

- Creates GitHub teams with customizable settings
- Manages team repository access and permissions
- Supports hierarchical team structures
- Configurable privacy levels

## Usage

```hcl
module "admin_team" {
  source = "./modules/github-teams"

  team_name    = "mbb-frontend-admin"
  description  = "Admin team for mbb-frontend repository"
  privacy      = "closed"
  repositories = ["mbb-frontend"]
  permission   = "admin"
}
```

## Inputs

| Name           | Description                                        | Type         | Default  | Required |
| -------------- | -------------------------------------------------- | ------------ | -------- | -------- |
| team_name      | Name of the GitHub team                            | string       | n/a      | yes      |
| description    | Description of the team                            | string       | ""       | no       |
| privacy        | Privacy level (secret/closed)                      | string       | "closed" | no       |
| repositories   | List of repository names this team has access to   | list(string) | []       | no       |
| permission     | Permission level (pull/triage/push/maintain/admin) | string       | "pull"   | no       |
| parent_team_id | Parent team ID for hierarchical structure          | number       | null     | no       |

## Outputs

| Name                    | Description                    |
| ----------------------- | ------------------------------ |
| team_id                 | The ID of the created team     |
| team_name               | The name of the created team   |
| team_slug               | The slug of the created team   |
| repository_associations | Map of repository associations |

## Resources Created

- `github_team.this` - GitHub team
- `github_team_repository.this` - Team repository access (one per repository)

## Requirements

- Terraform >= 1.14.5
- GitHub Provider ~> 6.0
- GitHub token with `admin:org` permissions
