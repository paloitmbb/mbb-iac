# Teams Data Management

## Overview

The `teams.yaml` file defines GitHub teams and their repository access permissions. Teams are created and managed via Terraform, while team membership is managed through GitHub REST API calls in the automated workflow.

## Team Naming Convention

All teams follow this naming pattern:

```
{repository-name}-{role}
```

### Roles and Permissions

| Role               | Suffix   | Permission | Description                                                      |
| ------------------ | -------- | ---------- | ---------------------------------------------------------------- |
| Admin              | `-admin` | `admin`    | Full administrative access including settings and team management |
| Developer          | `-dev`   | `push`     | Write access for development activities                          |
| Test Manager       | `-test`  | `push`     | Write access for testing activities                              |
| Production Manager | `-prod`  | `maintain` | Maintain access for production releases and management           |

## Automatic Team Creation

When a new repository is created via the automated workflow, the system automatically:

1. Creates 4 teams for the repository following the naming convention
2. Assigns appropriate permissions to each team
3. Populates the admin team with users specified in the repository request
4. Updates this YAML file with the new team definitions

## Manual Team Management

To manually add teams:

1. Edit `data/teams.yaml`
2. Add team definition following the structure:

   ```yaml
   - name: {repo-name}-{role}
     repository: {repo-name}
     permission: {admin|push|maintain}
     privacy: closed
     description: "{Role} team for {repo-name} repository"
   ```

3. Run Terraform: `./scripts/plan.sh dev` then `./scripts/apply.sh dev`

## Team Membership Management

Team memberships are **NOT** managed in this file or via Terraform. Use GitHub UI or API to:

- Add/remove team members
- Assign team maintainers
- Configure team settings

The automated workflow handles admin team membership population during repository creation.

## Example Team Structure

For a repository named `mbb-web-portal`, the following teams would be created:

```yaml
teams:
  - name: mbb-web-portal-admin
    repository: mbb-web-portal
    permission: admin
    privacy: closed
    description: "Admin team for mbb-web-portal repository - full administrative access"

  - name: mbb-web-portal-dev
    repository: mbb-web-portal
    permission: push
    privacy: closed
    description: "Developer team for mbb-web-portal repository - write access for development"

  - name: mbb-web-portal-test
    repository: mbb-web-portal
    permission: push
    privacy: closed
    description: "Test team for mbb-web-portal repository - write access for testing activities"

  - name: mbb-web-portal-prod
    repository: mbb-web-portal
    permission: maintain
    privacy: closed
    description: "Production team for mbb-web-portal repository - maintain access for production releases"
```

## Troubleshooting

### Team Already Exists Error

If Terraform reports that a team already exists:

1. Check if the team exists in GitHub organization
2. Import existing team: `terraform import 'module.repository_teams["team-name"].github_team.this' <team-id>`
3. Or remove from YAML if not needed

### Permission Issues

If team permissions are not applied correctly:

1. Verify the permission level is valid (pull/triage/push/maintain/admin)
2. Ensure repository exists before applying team permissions
3. Check GitHub token has `admin:org` permissions

### Team Membership Not Updating

Team membership is managed separately from this file:

- Use GitHub UI: Organization → Teams → [Team Name] → Members
- Use GitHub API: `gh api /orgs/{org}/teams/{team}/memberships/{username}`
- Or use the automated workflow when creating repositories
