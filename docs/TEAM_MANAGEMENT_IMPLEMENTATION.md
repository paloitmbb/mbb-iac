# Team Management Implementation Summary

This document summarizes the Terraform-based team management system implementation.

## Architecture Overview

```
Issue Template Submission
       ↓
Repository Dispatch Event
       ↓
Validation & PR Creation Workflow
       ↓
Pull Request Created (with teams.yaml changes)
       ↓
Terraform Plan (on PR)
       ↓
Approval & Merge
       ↓
Terraform Apply (on merge to main)
       ↓
Teams Updated in GitHub
```

## Components Created

### 1. Terraform Module: `modules/github-team`

**Purpose**: Manages GitHub teams and their configurations

**Features**:
- Create teams with name, description, and privacy settings
- Add members and maintainers to teams
- Grant teams repository access with specific permissions
- Support team deletion (soft delete via `deleted` flag)

**Files**:
- `main.tf` - Team, membership, and repository access resources
- `variables.tf` - Input variable definitions
- `outputs.tf` - Team ID and slug outputs
- `versions.tf` - Provider and Terraform version requirements
- `README.md` - Module documentation

**Usage**:
```hcl
module "github_teams" {
  source   = "./modules/github-team"
  for_each = { for team in local.all_teams : team.name => team }
  
  team_name    = each.value.name
  description  = each.value.description
  privacy      = each.value.privacy
  maintainers  = each.value.maintainers
  members      = each.value.members
  repositories = each.value.repositories
  deleted      = each.value.deleted
}
```

### 2. Data File: `data/teams.yaml`

**Purpose**: Central configuration for all managed GitHub teams

**Structure**:
```yaml
teams:
  - name: team-slug
    description: "Team description"
    privacy: closed
    maintainers: [user1, user2]
    members: [user3, user4]
    repositories:
      - repository: repo-name
        permission: push
```

**Features**:
- YAML format for easy readability and version control
- Loaded dynamically by Terraform
- Teams processed via `for_each` loop in root module
- All fields normalized with defaults in root module

### 3. Root Module Updates: `main.tf`

**Changes**:
- Added `locals` block to load and normalize teams from `data/teams.yaml`
- Added `module "github_teams"` block to instantiate team module for each team
- Module depends on organization and repository modules

**Team Loading Logic**:
```hcl
locals {
  teams_file = "${path.module}/data/teams.yaml"
  teams_data = try(yamldecode(file(local.teams_file)), { teams = [] })
  
  all_teams = [
    for team in local.teams_data.teams : merge(team, {
      description  = try(team.description, "")
      privacy      = try(team.privacy, "closed")
      maintainers  = try(team.maintainers, [])
      members      = try(team.members, [])
      repositories = try(team.repositories, [])
      deleted      = try(team.deleted, false)
    })
  ]
}
```

### 4. Workflow: Validation & PR Creation

**File**: `.github/workflows/team-management-validate-pr.yml`

**Trigger**: `repository_dispatch` event with type `team-management-terraform`

**Workflow Steps**:

1. **Parse Issue Form**
   - Extracts request type, team name, repository, permission, justification
   - Normalizes team/repo names to lowercase with hyphens

2. **Validate Request**
   - Validates request type against allowed options
   - Checks team existence (GitHub API + teams.yaml)
   - Checks repository existence
   - Validates user/member existence in organization
   - Posts validation results to issue

3. **Handle Validation Failure**
   - Posts error summary to issue
   - Adds `validation-failed` label
   - Closes issue as "not_planned"

4. **Create/Update PR** (if validation passes)
   - Loads current `data/teams.yaml`
   - Applies changes based on request type:
     - **Create team**: Adds new team entry
     - **Delete team**: Removes team entry
     - **Give access**: Adds repository to team's access list
     - **Remove access**: Removes repository from team's access list
   - Creates branch: `team-management/issue-<number>-<team-name>`
   - Creates or updates PR with changes
   - Posts PR link to issue

**Request Type Handling**:

| Request Type | Action |
|---|---|
| Create new team | Add team to teams.yaml with maintainer as requestor |
| Delete team | Remove team from teams.yaml |
| Give team access | Add repository entry to team.repositories |
| Remove team access | Remove repository entry from team.repositories |

**Outputs**:
- PR number
- Validation passed/failed status
- Errors and validation results

### 5. Workflow: Terraform Plan & Apply

**File**: `.github/workflows/team-management-terraform.yml`

**Separate Workflow for Team Management**:
- Does not conflict with other Terraform workflows
- Only triggers on changes to team-related files
- Isolated `team-management-plan` and `team-management-apply` environments

**Triggers**:
- **Terraform Plan**: On PR (if `data/teams.yaml`, `modules/github-team/**`, or `main.tf` changed)
- **Terraform Apply**: On push to main (same file paths)

**Terraform Plan Steps**:
1. Checkout code
2. Setup Terraform 1.14.5
3. Format check: `terraform fmt -check -recursive`
4. Initialize: `./scripts/init.sh dev`
5. Validate: `terraform validate`
6. Plan: `terraform plan -out=tfplan`
7. Post plan output to PR as comment

**Terraform Apply Steps**:
1. Checkout code
2. Setup Terraform 1.14.5
3. Initialize: `./scripts/init.sh dev`
4. Validate: `terraform validate`
5. Apply: `terraform apply -auto-approve`
6. Generate apply summary

**Environments**:
- `team-management-plan` - For terraform plan (read-only)
- `team-management-apply` - For terraform apply (requires approval)

### 6. Issue Template: `ISSUE_TEMPLATE/team-management-terraform.yml`

**Purpose**: Collect team management requests from users

**Form Fields**:
- **Request Type** (dropdown): Create, delete, give access, remove access
- **Team** (text): Team slug/name
- **Repository** (text): Repository name
- **Permission Level** (dropdown): pull, push, repo-owner
- **Justification** (textarea): Reason for request
- **Acknowledgment** (checkbox): Confirm approval requirement

**Request Type Guidance Table**:

| Request Type | Team Required | Repository Required | Permission Used |
|---|---|---|---|
| Create new team | Yes (must NOT exist) | No | No |
| Delete team | Yes (must exist) | No | No |
| Give team access | Yes (must exist) | Yes (must exist) | Yes |
| Remove team access | Yes (must exist) | Yes (must exist) | No |

### 7. Documentation

**Files Created**:
- `data/TEAM_MANAGEMENT.md` - Comprehensive user guide
- `docs/TEAM_MANAGEMENT_IMPLEMENTATION.md` - This file

## Data Flow

### Creating a Team

```
1. User submits "Create new team" issue
2. Workflow parses: team=my-team, requestor=alice
3. Validation checks: team doesn't exist, alice is org member ✅
4. Workflow creates PR:
   - teams.yaml updated with: name: my-team, maintainers: [alice]
5. PR goes through review
6. Terraform plan shows: +1 github_team, +1 github_team_membership
7. PR approved and merged
8. Terraform apply: Team created in GitHub, alice added as maintainer
```

### Granting Repository Access

```
1. User submits "Give team access to a repository" issue
2. Workflow parses: team=developers, repo=api, permission=push
3. Validation checks: team exists, repo exists ✅
4. Workflow creates PR:
   - teams.yaml updated: add {repository: api, permission: push} to developers.repositories
5. Terraform plan shows: +1 github_team_repository
6. PR merged
7. Terraform apply: Team granted push access to api repo
```

### Removing Team Access

```
1. User submits "Remove team access to a repository" issue
2. Workflow parses: team=interns, repo=prod-configs
3. Validation checks: team exists, repo exists ✅
4. Workflow creates PR:
   - teams.yaml updated: remove api entry from interns.repositories
5. Terraform plan shows: -1 github_team_repository
6. PR merged
7. Terraform apply: Team removed from repository
```

### Deleting a Team

```
1. User submits "Delete team" issue
2. Workflow parses: team=deprecated
3. Validation checks: team exists ✅
4. Workflow creates PR:
   - teams.yaml updated: remove deprecated team entirely
5. Terraform plan shows: -1 github_team, -N github_team_membership
6. PR merged
7. Terraform apply: Team deleted from GitHub
```

## Files Modified/Created

### New Files Created

```
modules/github-team/
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
└── README.md

data/
├── teams.yaml
└── TEAM_MANAGEMENT.md

.github/workflows/
├── team-management-validate-pr.yml
└── team-management-terraform.yml

docs/
└── TEAM_MANAGEMENT_IMPLEMENTATION.md
```

### Files Modified

```
main.tf - Added teams loading locals and module instantiation
```

## Configuration Requirements

### Environment Variables (Workflows)

**team-management-validate-pr.yml**:
- `GITHUB_TOKEN` (built-in)
- `ORG_GITHUB_TOKEN` (secret) - For GitHub API calls, requires `admin:org`, `repo`

**team-management-terraform.yml**:
- `GITHUB_TOKEN` (built-in)
- `ORG_GITHUB_TOKEN` (secret) - For GitHub provider
- `ARM_SUBSCRIPTION_ID` (secret) - Azure backend
- `ARM_TENANT_ID` (secret) - Azure backend
- `ARM_CLIENT_ID` (secret) - Azure backend
- `ARM_CLIENT_SECRET` (secret) - Azure backend

### GitHub Secrets Required

Set these in your GitHub organization:
- `ORG_GITHUB_TOKEN` - Personal access token with `admin:org`, `repo` scopes
- `ARM_SUBSCRIPTION_ID` - Azure subscription ID
- `ARM_TENANT_ID` - Azure tenant ID
- `ARM_CLIENT_ID` - Azure service principal ID
- `ARM_CLIENT_SECRET` - Azure service principal secret

### GitHub Environments

Set up these environments with approval requirements:
- `team-management-plan` - For terraform plan (optional approval)
- `team-management-apply` - For terraform apply (recommended approval)

## Using the System

### For End Users

1. Navigate to Issues in the repository
2. Click "New Issue"
3. Select "Team Management Request" template
4. Fill in the form with your request
5. Submit the issue
6. Wait for validation (should see comment within seconds)
7. If validation passes, check for PR link in issue comment
8. Review PR and Terraform plan
9. Once approved and merged, changes apply automatically

### For Operators

1. Ensure all secrets are configured in GitHub
2. Create the two GitHub environments with approval settings
3. Monitor workflows for any failures
4. Review Terraform plans before merging PRs
5. Periodically audit `data/teams.yaml` for accuracy

## Integration with Existing Workflows

This implementation is completely separate from other Terraform workflows:

- **Isolated trigger paths**: Only reacts to changes in team-related files
- **Separate environments**: Uses distinct approval environments
- **Independent state**: Teams managed in same Terraform state but logical separation
- **No conflicts**: Can run simultaneously with repository management workflows

## Security Considerations

1. **Soft Delete**: Teams are removed by setting `deleted = true`, allowing recovery
2. **Approval Gates**: Apply environment has approval gate (recommend enabling)
3. **Audit Trail**: All changes go through PR with commit history
4. **Validation**: Comprehensive validation before PR creation
5. **Least Privilege**: Teams configured with appropriate permissions
6. **Secrets Management**: Uses GitHub secrets for credentials
7. **RBAC**: Teams manage access with role-based permissions

## Next Steps

1. **Configure GitHub Secrets**: Set required secrets for authenticating with GitHub and Azure
2. **Create GitHub Environments**: Set up `team-management-plan` and `team-management-apply`
3. **Test Workflow**: Submit a test issue to validate the flow
4. **Document Teams**: Update `data/teams.yaml` with existing teams or leave as examples
5. **Train Team**: Share `data/TEAM_MANAGEMENT.md` with team members

## Troubleshooting

See `data/TEAM_MANAGEMENT.md` for detailed troubleshooting guide and best practices.

## Related Files

- [Team Management User Guide](../../data/TEAM_MANAGEMENT.md)
- [GitHub Team Module](../../modules/github-team/README.md)
- [Issue Template](../../ISSUE_TEMPLATE/team-management-terraform.yml)
- [Validation & PR Workflow](../../.github/workflows/team-management-validate-pr.yml)
- [Terraform Plan & Apply Workflow](../../.github/workflows/team-management-terraform.yml)
