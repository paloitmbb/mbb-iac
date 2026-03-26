# Team Management Guide

This guide explains how to manage GitHub teams using the Terraform-based team management system.

## Overview

The team management system allows you to:
- **Create new teams**
- **Grant teams access to repositories**
- **Revoke teams access from repositories**
- **Delete teams**
- **Manage team members** (maintainers and members)

## How It Works

### 1. Issue Template Submission

Submit a team management request using the **Team Management Request** issue template:

- **Request Type**: Select the type of operation (create, delete, give access, remove access)
- **Team**: Provide the team name/slug
- **Repository**: Provide the repository name (for access requests)
- **Permission**: Select the permission level (pull, push, repo-owner)
- **Justification**: Explain the reason for the request

### 2. Validation Workflow

When you submit the issue:
1. A `repository_dispatch` event is triggered (via GitHub Actions)
2. The **validate-pr** workflow:
   - Parses the issue form data
   - Validates all fields (team exists, repo exists, etc.)
   - Posts validation results to the issue as a comment
   - If validation fails, closes the issue

### 3. PR Creation and Changes

If validation passes:
1. The workflow updates `data/teams.yaml` based on your request
2. A pull request is created with the changes
3. A comment is posted to the issue with the PR link

### 4. Terraform Plan

When the PR is created:
1. GitHub Actions runs `terraform plan`
2. The plan output is posted as a comment on the PR
3. Review the plan to see exactly what will be created/modified

### 5. Approval and Merge

1. Review the PR changes and the Terraform plan
2. Get approval from DevSecOps team
3. Merge the PR to the main branch

### 6. Terraform Apply

Once the PR is merged:
1. GitHub Actions automatically runs `terraform apply`
2. Terraform executes the changes in GitHub
3. Teams are created, deleted, or permissions are modified accordingly

## Teams Configuration File

Teams are defined in `data/teams.yaml` using this structure:

```yaml
teams:
  - name: team-slug                    # Required: lowercase, alphanumeric, hyphens
    description: "Team description"    # Required: human-readable description
    privacy: closed                    # Required: closed or secret
    maintainers:                       # Required: list of GitHub usernames
      - alice
      - bob
    members:                           # Required: list of GitHub usernames
      - carol
      - dave
    repositories:                      # Required: list of repos the team has access to
      - repository: repo1
        permission: push               # Required: pull, push, repo-owner, triage, maintain, admin
      - repository: repo2
        permission: pull
```

## Request Types

### 1. Create New Team

**When to use**: Creating a new GitHub team

**Fields required**:
- Team (must NOT exist)
- Justification

**Example**:
```
Request Type: Create new team
Team: mbb-web-portal-dev
Justification: New team for web portal development team
```

**Action**: Creates team with requestor as maintainer

### 2. Delete Team

**When to use**: Removing a team from the organization

**Fields required**:
- Team (must exist)
- Justification

**Example**:
```
Request Type: Delete team
Team: deprecated-team
Justification: Team is no longer needed after project closure
```

**Action**: Removes team from teams.yaml and GitHub

### 3. Give Team Access to Repository

**When to use**: Granting a team access to a repository

**Fields required**:
- Team (must exist)
- Repository (must exist)
- Permission Level
- Justification

**Permission Levels**:
- `pull` - Read-only access (recommended for review teams)
- `push` - Read-write access (recommended for development teams)
- `repo-owner` - Full repository ownership

**Example**:
```
Request Type: Give team access to a repository
Team: developers
Repository: mbb-api
Permission Level: push
Justification: Dev team needs write access to the API repository
```

**Action**: Adds repository to team's access list in teams.yaml

### 4. Remove Team Access from Repository

**When to use**: Revoking a team's access to a repository

**Fields required**:
- Team (must exist)
- Repository (must exist)
- Justification

**Example**:
```
Request Type: Remove team access to a repository
Team: interns
Repository: production-configs
Justification: Removing access after internship completion
```

**Action**: Removes repository from team's access list in teams.yaml

## Manual Updates to teams.yaml

While it's recommended to use the issue template for consistency, you can also manually edit `data/teams.yaml`:

1. Pull the latest changes: `git pull origin main`
2. Edit `data/teams.yaml` to make changes
3. Commit with a conventional message: `git commit -m "chore(teams): update team configurations"`
4. Push to create a branch: `git push origin my-branch`
5. Create a PR from your branch
6. The terraform plan will run automatically
7. Review, approve, and merge

## Viewing Current Teams

To view all currently managed teams:

```bash
cat data/teams.yaml
```

To view teams in GitHub:

```bash
# List all teams in the organization
gh team list

# Get details on a specific team
gh team view <team-slug>
```

## Terraform Module Details

The `modules/github-team` module manages:
- **Team Creation**: Creates GitHub teams with name, description, and privacy settings
- **Team Membership**: Assigns maintainers and members to teams
- **Repository Access**: Grants team access to repositories with specified permissions
- **Team Deletion**: Removes teams by setting `deleted = true`

See [modules/github-team/README.md](../../modules/github-team/README.md) for technical details.

## Workflows

### Validation and PR Creation Workflow

**File**: `.github/workflows/team-management-validate-pr.yml`

**Triggered by**: `repository_dispatch` event with type `team-management-terraform`

**Actions**:
1. Parses issue form data
2. Validates inputs
3. Updates `data/teams.yaml`
4. Creates/updates PR with changes
5. Posts summary to issue

### Terraform Plan and Apply Workflow

**File**: `.github/workflows/team-management-terraform.yml`

**Triggers**:
- **Terraform Plan**: On PR creation/update (if `data/teams.yaml` changed)
- **Terraform Apply**: On push to main branch (if `data/teams.yaml` changed)

**Actions**:
1. Runs `terraform fmt -check` to verify code formatting
2. Runs `terraform validate` to check syntax
3. Runs `terraform plan` and posts output to PR
4. On merge: Runs `terraform apply` to execute changes

## Troubleshooting

### PR Not Being Created

**Issue**: Issue validation passes but no PR is created

**Solutions**:
- Check that `data/teams.yaml` file exists
- Verify YAML syntax is valid
- Check repository permissions for the workflow

### Terraform Plan Shows Errors

**Issue**: Terraform plan fails

**Solutions**:
- Check GitHub token permissions (needs `admin:org`, `repo`)
- Verify team/repository names are correct
- Check Azure backend configuration

### Team Not Appearing in GitHub

**Issue**: Team created but not visible in GitHub org

**Solutions**:
- Check Terraform apply workflow completed successfully
- Verify team name matches expected format (lowercase, alphanumeric)
- Check organization member count limits

## Best Practices

1. **Use lowercase team names**: GitHub automatically slugifies team names to lowercase with hyphens
2. **Clear descriptions**: Always provide clear team descriptions
3. **Permission principle of least privilege**: Grant minimum necessary permissions
4. **Regular reviews**: Periodically review team membership and repository access
5. **Document teams**: Keep the teams.yaml file well-organized and commented
6. **Approval workflow**: Always get approval before merging team changes

## Permissions Reference

| Permission | Use Case |
|-----------|----------|
| `pull` | Read-only access (review, audit teams) |
| `push` | Read-write access (development teams) |
| `repo-owner` | Full access & settings (DevOps, admin teams) |
| `triage` | Manage issues, PRs, labels |
| `maintain` | Manage without delete capability |
| `admin` | Full administrative access |

## Examples

### Example 1: Create Development Team

```yaml
- name: web-portal-devs
  description: "Web Portal Development Team"
  privacy: closed
  maintainers:
    - team-lead
  members:
    - developer1
    - developer2
    - developer3
  repositories:
    - repository: mbb-web-portal
      permission: push
    - repository: mbb-api
      permission: push
    - repository: terraform-configs
      permission: pull
```

### Example 2: Create Security Review Team

```yaml
- name: security-reviewers
  description: "Security Review and Audit Team"
  privacy: secret
  maintainers:
    - security-lead
  members:
    - auditor1
    - auditor2
  repositories:
    - repository: mbb-api
      permission: pull
    - repository: security-policies
      permission: pull
```

## Related Documentation

- [GitHub Teams API](https://docs.github.com/en/rest/teams)
- [Terraform GitHub Provider - Team](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/team)
- [GitHub Team Permissions](https://docs.github.com/en/organizations/managing-access-to-your-organizations-repositories/repository-permission-levels-for-an-organization)
