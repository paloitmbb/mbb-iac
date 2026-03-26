# github-team Terraform Module

## Purpose

This module manages GitHub teams, their membership (maintainers and members), and repository access in an organization. It supports creating teams, managing team membership, granting repository access, and marking teams for deletion.

## Requirements

- Terraform >= 1.14.5
- GitHub Provider ~> 6.0

## Usage

### Create Team with Members and Repository Access

```hcl
module "github_team" {
  source      = "../github-team"
  team_name   = "mbb-web-portal-dev"
  description = "Web Portal Development Team"
  privacy     = "closed"
  maintainers = ["alice", "bob"]
  members     = ["carol"]
  repositories = [
    {
      repository = "mbb-web-portal"
      permission = "push"
    },
    {
      repository = "mbb-api"
      permission = "pull"
    }
  ]
}
```

### Delete Team (Soft Delete)

```hcl
module "github_team" {
  source    = "../github-team"
  team_name = "old-team"
  deleted   = true
}
```

## Inputs

| Name         | Description                                           | Type         | Default   |
|--------------|-------------------------------------------------------|--------------|-----------|
| team_name    | Name (slug) of the team                               | string       | n/a       |
| description  | Description of the team                               | string       | ""        |
| privacy      | Team privacy: closed or secret                        | string       | "closed"  |
| maintainers  | List of usernames to assign as maintainers            | list(string) | []        |
| members      | List of usernames to assign as members                | list(string) | []        |
| repositories | List of repos with permissions to grant team access   | list(object) | []        |
| deleted      | Mark team for deletion (soft delete)                  | bool         | false     |

### Repository Object Schema

```hcl
{
  repository = string  # Required: Repository name
  permission = string  # Required: pull, push, repo-owner, triage, maintain, admin
}
```

## Outputs

| Name      | Description                |
|-----------|----------------------------|
| team_id   | The ID of the team         |
| team_slug | The slug of the team       |

## Resources

- github_team (conditional - not created if deleted=true)
- github_team_membership (conditional - members and maintainers)
- github_team_repository (conditional - repository access)
