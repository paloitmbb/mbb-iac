# Team Management Quick Start

This guide walks you through setting up and using the Terraform-based team management system.

## Prerequisites

✅ GitHub organization admin access
✅ Terraform knowledge (basic)
✅ Azure subscription (for backend state)

## Setup (One-Time)

### 1. Configure GitHub Secrets

Add these secrets to your GitHub organization settings:

```bash
# Generate a GitHub PAT with necessary scopes
# Scopes: admin:org, repo, workflow

Settings > Developer settings > Personal access tokens > New token
```

Then add to organization settings:
- Go to **Settings > Secrets and variables > Actions**
- Add these secrets:

| Secret Name | Value | Scopes Needed |
|---|---|---|
| `ORG_GITHUB_TOKEN` | GitHub PAT | `admin:org`, `repo` |
| `ARM_SUBSCRIPTION_ID` | Your Azure subscription ID | N/A |
| `ARM_TENANT_ID` | Your Azure tenant ID | N/A |
| `ARM_CLIENT_ID` | Azure service principal ID | N/A |
| `ARM_CLIENT_SECRET` | Azure service principal secret | N/A |

### 2. Create GitHub Environments

Set up approval gates for safety:

**For `team-management-plan` environment** (optional):
1. Go to **Settings > Environments**
2. Click **New environment**
3. Name: `team-management-plan`
4. (Optional) Enable "Required reviewers" and add DevSecOps team

**For `team-management-apply` environment** (recommended):
1. Go to **Settings > Environments**
2. Click **New environment**
3. Name: `team-management-apply`
4. Enable "Required reviewers"
5. Add DevSecOps team as required reviewers
6. Set deployment branches to `main` only

### 3. Verify Workflows

Check that workflows are in place:

```bash
# Verify workflow files exist
ls -la .github/workflows/team-management*.yml

# Output should show:
# - team-management-validate-pr.yml
# - team-management-terraform.yml
```

### 4. Verify Module

Check that team module exists:

```bash
# Verify module files exist
ls -la modules/github-team/

# Output should show:
# - main.tf
# - variables.tf
# - outputs.tf
# - versions.tf
# - README.md
```

## First Use: Create a Team

### Step 1: Navigate to Issues

1. Open your GitHub repository
2. Go to **Issues**
3. Click **New issue**
4. Look for "Team Management Request" template

> If you don't see the template, the ISSUE_TEMPLATE file may not be in place. Create it from `.github/ISSUE_TEMPLATE/team-management-terraform.yml`

### Step 2: Fill Out the Form

Example: Creating a development team

```
Request Type: Create new team
Team: mbb-developers
Justification: Core development team for web portal project
Acknowledgment: ✅ Both checkboxes
```

### Step 3: Submit Issue

Click **Submit new issue**

### Step 4: Wait for Validation

Within 30 seconds, you should see:
1. Validation summary comment
2. `validation-passed` label added

### Step 5: Review PR

Click the PR link in the validation comment

### Step 6: Review Terraform Plan

Scroll through the PR to find the Terraform plan comment. It should show:

```
+resource "github_team" "this":
    name = "mbb-developers"
    ...

+resource "github_team_membership" "maintainers":
    username = "your-username"
    role = "maintainer"
    ...
```

### Step 7: Approve & Merge

1. Click **Approve** on the PR
2. Wait for all checks to pass
3. Click **Merge pull request**

### Step 8: Verify Completion

1. Go back to the GitHub organization
2. Click **Teams**
3. You should see the new `mbb-developers` team

## Common Tasks

### Grant Team Access to Repository

1. Submit new issue with template
2. Select: **Give team access to a repository**
3. Fill in:
   - Team: `mbb-developers` (must exist)
   - Repository: `mbb-api` (must exist)
   - Permission Level: `push`
   - Justification

### Remove Team Access

Similar to above but select **Remove team access to a repository**

### Delete Team

1. Submit issue with template
2. Select: **Delete team**
3. Team must currently exist
4. Merge PR to apply

### Add Team Members

Currently, team members must be added via `data/teams.yaml` directly or by:
1. Creating issue to create team with initial maintainer
2. Manually editing `data/teams.yaml` to add members
3. Submitting PR with changes to members list

Example manual edit:
```yaml
- name: developers
  maintainers:
    - alice              # Changed from ["alice"] to add below
    - bob               # New maintainer
  members:
    - carol             # New member
```

## Workflow Progress Tracking

### Issue Comments Timeline

1. **0-10 seconds**: Validation summary posted
   - Shows if validation passed or failed
   - Lists all validation checks

2. **PR Creation**: PR link posted (if validation passed)
   - Links to PR with teams.yaml changes
   - Shows exact change being made

3. **On PR**: Terraform plan posted
   - Shows resources being created/modified/deleted
   - Review this carefully before merging

4. **On Merge**: Terraform apply runs
   - Executes changes in GitHub
   - Process is automatic

### Checking Workflow Status

If PR isn't created within minutes:

1. Check workflow status: **Actions** tab
2. Look for `team-management-validate-pr` workflow
3. If failed, click to see error details
4. Common issues:
   - GitHub PAT expired or insufficient permissions
   - Team/repo names invalid
   - YAML syntax error in teams.yaml

## Advanced: Manual teams.yaml Edits

For power users who want to make multiple changes at once:

### Step 1: Clone and Branch

```bash
git clone <repo>
cd mbb-iac
git checkout -b teams/batch-update
```

### Step 2: Edit teams.yaml

```yaml
teams:
  - name: developers
    description: "Development team"
    privacy: closed
    maintainers: [alice, bob]
    members: [carol, dave]
    repositories:
      - repository: mbb-api
        permission: push
      - repository: mbb-web-portal
        permission: push

  - name: devops
    description: "DevOps team"
    privacy: closed
    maintainers: [ops-lead]
    members: []
    repositories:
      - repository: terraform-configs
        permission: push
```

### Step 3: Commit and Push

```bash
git add data/teams.yaml
git commit -m "chore(teams): add developers and devops teams"
git push origin teams/batch-update
```

### Step 4: Create PR

- Go to GitHub
- Create PR from your branch
- Terraform plan will run automatically
- Review and merge

## Permissions by Role

| Permission | Can Do | Cannot Do |
|---|---|---|
| `pull` | Read code, review PRs | Create branches, push code |
| `push` | Read & write code, create branches | Delete branches, change settings |
| `repo-owner` | Everything | N/A |

For most teams, use `push`. Use `pull` for review/audit teams.

## Best Practices

### ✅ DO

- Use lowercase team names with hyphens
- Provide clear descriptions
- Grant minimum necessary permissions
- Review Terraform plans before merging
- Document team purpose in description
- Request one change per issue
- Update teams.yaml with team membership regularly

### ❌ DON'T

- Use uppercase in team names (GitHub will slug it anyway)
- Grant `repo-owner` access unnecessarily
- Merge PRs without reviewing Terraform plan
- Use teams for individual user access control
- Forget to update Justification field
- Mix multiple team operations in one issue

## Troubleshooting

### Issue: Workflow ran but no PR created

**Solution**:
1. Check action logs: **Actions** > `team-management-validate-pr`
2. Look for error in logs
3. Common causes:
   - Invalid team name characters
   - Team already exists (for create)
   - Team doesn't exist (for modify/delete)
   - Repository doesn't exist
   - YAML syntax error in teams.yaml

### Issue: PR created but Terraform plan didn't run

**Solution**:
1. Check PR for workflow status
2. Workflow should show `team-management-terraform` status
3. If not triggered, check:
   - Branch path matches: `data/teams.yaml`, `modules/github-team/**`, or `main.tf`
   - Workflow file is not commented out
   - GitHub Actions enabled in repo

### Issue: Terraform apply failed

**Solution**:
1. Click on Apply workflow run
2. Check logs for error
3. Common causes:
   - GitHub token expired
   - Insufficient permissions
   - Team already exists/doesn't exist
   - Repository missing
4. Contact DevSecOps team

## Next Steps

1. ✅ Set up secrets and environments
2. ✅ Create your first team using issue template
3. ✅ Grant team access to repositories
4. ✅ Share this guide with your team
5. ✅ Set up approval workflow in team-management-apply environment

## Getting Help

- **Workflow Issues**: Check `.github/workflows/team-management*.yml`
- **Module Issues**: Check `modules/github-team/README.md`
- **Data Format**: Check `data/teams.yaml` example
- **User Guide**: Read `data/TEAM_MANAGEMENT.md`
- **Implementation Details**: See `docs/TEAM_MANAGEMENT_IMPLEMENTATION.md`

## Related Documents

- [Team Management User Guide](../data/TEAM_MANAGEMENT.md)
- [GitHub Team Module](../modules/github-team/README.md)
- [Implementation Details](TEAM_MANAGEMENT_IMPLEMENTATION.md)
- [GitHub Teams API Docs](https://docs.github.com/en/rest/teams)
