# Automated Repository Workflow - Implementation Summary

**Date:** 12 February 2026  
**Status:** ✅ Implementation Complete (Updated with Simplified Form)

## What Was Implemented

This implementation creates an issue-driven automated workflow for repository creation with team management, following the plan in [02-AUTOMATED_REPO_WORKFLOW_PLAN.md](./02-AUTOMATED_REPO_WORKFLOW_PLAN.md).

**Key Design Decision:** The form has been simplified to only request essential information. All other repository settings use default values from existing repositories in `data/repositories.yaml`, ensuring consistency and reducing complexity.

## Files Created

### 1. GitHub Teams Terraform Module

**Location:** `modules/github-teams/`

- ✅ `main.tf` - Team and repository access resources
- ✅ `variables.tf` - Input variables with validation
- ✅ `outputs.tf` - Team information outputs
- ✅ `versions.tf` - Provider version requirements
- ✅ `README.md` - Module documentation

**Features:**

- Creates GitHub teams with configurable settings
- Manages team repository access permissions
- Supports hierarchical team structures
- Validates team names and permission levels

### 2. Data Files

**Location:** `data/`

- ✅ `teams.yaml` - YAML configuration for team definitions
- ✅ `TEAMS.md` - Teams data management documentation
### 2. Data Files

**Location:** `data/`

- ✅ `teams.yaml` - YAML configuration for team definitions
- ✅ `TEAMS.md` - Teams data management documentation
- ✅ `defaults.yaml` - Default repository configuration for automated workflow

**Teams Structure:**

```yaml
teams:
  - name: {repo-name}-dev
    repository: {repo-name}
    permission: push
    privacy: closed
    description: "Developer team for {repo-name} repository"
```

**Defaults Structure:**

```yaml
repository_defaults:
  visibility: private
  features:
    has_issues: true
    has_projects: true
    has_wiki: false
  security:
    enable_vulnerability_alerts: true
    enable_dependabot_alerts: true
    enable_dependabot_security_updates: true
  topics:
    - maybank
    - mbb
```

### 3. Root Module Updates

**File:** `main.tf`

- ✅ Added teams configuration loading from YAML
- ✅ Integrated DevSecOps team module (admin access to all repos)
- ✅ Integrated repository-specific teams module

**File:** `outputs.tf`

- ✅ Added DevSecOps team output
- ✅ Added repository teams output map
- ✅ Added team count output

### 4. GitHub Issue Template

**File:** `.github/ISSUE_TEMPLATE/new-repository.yml`

**Simplified form with essential fields only:**

- ✅ Repository name (required)
- ✅ Team maintainers/admins (optional - defaults to issue creator)
- ✅ Tech stack dropdown with "Others" option (required)
- ✅ Business justification field (required)
- ✅ Default branch selection (required)
- ✅ Acknowledgment checkboxes (required)

**Default Values Strategy:**
All repository settings not requested in the form (visibility, features, security, topics, variables) use default values from `data/defaults.yaml`. This provides:
- Explicit and centralized default configuration
- Simplified user experience
- Consistency across repositories
- Reduced form complexity
- Easy maintenance of organizational defaults
- No dependency on existing repositories

**Removed fields (now use defaults):**
- ❌ Repository description (auto-generated)
- ❌ Visibility selection (uses default: private)
- ❌ Target environment selection (uses default)
- ❌ Feature checkboxes (uses defaults)
- ❌ Security feature checkboxes (uses defaults)
- ❌ Topics input (uses defaults + tech stack)
- ❌ Branch protection settings (uses defaults)
- ❌ Additional notes (not needed)

### 5. GitHub Actions Workflow

**File:** `.github/workflows/repo-request.yml`

Implemented two-job workflow:

**Job 1: Validation (validate-request)**

- ✅ Parse issue body to extract simplified fields (name, admins, tech stack, justification, default branch)
- ✅ Load default values from `defaults.yaml`
- ✅ Validate repository name format (lowercase, hyphens only)
- ✅ Validate admin usernames exist in GitHub
- ✅ Check repository doesn't already exist
- ✅ Post validation results comment to issue
- ✅ Add validation status labels
- ✅ Close issue if validation fails

**Job 2: Creation (create-repository)**

- ✅ Requires approval via GitHub Environment
- ✅ Merge issue form data with default values from template
- ✅ Generate description from repository name and tech stack
- ✅ Update `repositories.yaml` with new repository (using defaults + form overrides)
- ✅ Update `teams.yaml` with 3 new teams
- ✅ Commit changes to main branch
- ✅ Run Terraform init and apply
- ✅ Assign team maintainers to all teams (defaults to issue creator)
- ✅ Post success/failure comments
- ✅ Close issue on completion

## Terraform Configuration Status

✅ **Validation:** All Terraform files validated successfully
✅ **Format:** All Terraform files formatted
✅ **Modules:** All modules initialized
✅ **Syntax:** No syntax errors

```
terraform validate
Success! The configuration is valid.
```

## Team Structure

For each repository created, 3 teams are automatically provisioned:

| Team Suffix | Permission | Description                        |
| ----------- | ---------- | ---------------------------------- |
| `-dev`      | `push`     | Developer write access             |
| `-test`     | `push`     | Test manager write access          |
| `-prod`     | `maintain` | Production manager maintain access |

**Team Maintainers:** The admins specified in the repository request become team maintainers for all 3 teams, with the ability to manage team membership. If no admins are specified, the issue requestor becomes the team maintainer.

## What Still Needs to Be Done

### 1. GitHub Environment Setup (Manual)

⚠️ **Required before workflow can run:**

1. Go to repository **Settings → Environments**
2. Create new environment: `repo-creation-approval`
3. Add required reviewers: `paloitmbb-devsecops` team
4. Set deployment branch pattern: `main`

**Why:** The workflow requires manual approval from DevSecOps team before creating resources.

### 2. Create DevSecOps Team (Manual or via Terraform)

Two options:

**Option A: Manual (Quick)**

1. Go to Organization → Teams
2. Create team: `paloitmbb-devsecops`
3. Add team members who should approve requests

**Option B: Via Terraform (Recommended)**

1. First create the team manually without repository access
2. Run `terraform apply` to grant admin access to all repos

### 3. Test the Workflow

After environment setup:

1. **Create a test issue** using the new template
2. **Fill in all required fields**
3. **Wait for validation comment**
4. **Approve the workflow** (if validation passed)
5. **Verify repository creation**
6. **Check teams were created**
7. **Confirm admin team populated**

### 4. Documentation Updates

Consider updating:

- Main README.md with workflow usage instructions
- CONTRIBUTING.md with repository request process
- Add troubleshooting section for common issues

## Architecture Flow

```
User Creates Issue (Simplified Form)
   - Repository name
   - Team maintainers
   - Tech stack
   - Justification
   - Default branch
       ↓
Validation Job (automatic)
   ✅ Validate name
   ✅ Validate maintainers
   ✅ Check existence
   ✅ Load defaults from defaults.yaml
   ✅ Post results
       ↓
Awaiting Approval (manual)
   ⏳ DevSecOps reviews
   ✅ Approves deployment
       ↓
Creation Job (automatic)
   ✅ Merge form data with defaults
   ✅ Generate description
   ✅ Update YAML files
   ✅ Commit to main
   ✅ Terraform apply
   ✅ Assign team maintainers
   ✅ Post success
   ✅ Close issue
       ↓
Repository Ready! 🎉
```

## Default Values Mechanism

**Default Configuration:** All default values are defined in `data/defaults.yaml` for centralized management.

**Current Defaults:**
```yaml
repository_defaults:
  visibility: private
  
  features:
    has_issues: true
    has_projects: true
    has_wiki: false
  
  security:
    enable_vulnerability_alerts: true
    enable_advanced_security: false
    enable_secret_scanning: false
    enable_secret_scanning_push_protection: false
    enable_dependabot_alerts: true
    enable_dependabot_security_updates: true
  
  topics:
    - maybank
    - mbb
  
  variables:
    ENVIRONMENT:
      value: production
```

**Field Merge Strategy:**
1. **From Defaults (defaults.yaml):** visibility, features, security, base topics, variables
2. **From Issue Form (overrides):** name, default_branch, tech stack
3. **Auto-generated:** description (from name + tech stack), topics (defaults + tech stack)
4. **Example:** New repo "mbb-payment-api" with "Java Springboot" gets:
   - Name: `mbb-payment-api`
   - Description: `Mbb Payment Api using Java Springboot`
   - Visibility: `private` (from defaults)
   - Features: Same as defaults
   - Security: Same as defaults
   - Topics: `[maybank, mbb, java-springboot]`
   - Default Branch: `main` (from form)

**Benefits:**
- ✅ Explicit and centralized default configuration
- ✅ Consistent security policies across all repos
- ✅ Standardized feature settings
- ✅ Minimal user input required
- ✅ Easy to update defaults (edit defaults.yaml)
- ✅ No dependency on existing repositories
- ✅ Can still override manually after creation

## Configuration Examples
   ✅ Validate name
   ✅ Validate maintainers
   ✅ Check existence
   ✅ Post results
       ↓
Awaiting Approval (manual)
   ⏳ DevSecOps reviews
   ✅ Approves deployment
       ↓
Creation Job (automatic)
   ✅ Update YAML files
   ✅ Commit to main
   ✅ Terraform apply
   ✅ Assign team maintainers
   ✅ Post success
   ✅ Close issue
       ↓
Repository Ready! 🎉
```

## Configuration Examples

### Example Repository Request

```markdown
Repository Name: mbb-payment-api
Description: Payment processing API service
Tech Stack: Java Springboot
Team Maintainers: john-doe, jane-smith
Visibility: private
Environment: dev
Features: ✓ Issues, ✓ Projects
Security: ✓ Dependabot, ✓ GHAS
```

### Resulting Teams

All teams with john-doe and jane-smith as maintainers:

- `mbb-payment-api-dev`
- `mbb-payment-api-test`
- `mbb-payment-api-prod`

## Security Considerations

✅ **Input Validation:** All user inputs validated before processing
✅ **Approval Required:** DevSecOps team must approve before creation
✅ **User Validation:** Admin usernames validated against GitHub
✅ **Repository Checks:** Ensures no duplicate repositories
✅ **Audit Trail:** All changes committed to Git history
✅ **Least Privilege:** Workflow uses minimum required permissions

## Benefits

1. **Self-Service:** Users can request repositories via simple form
2. **Consistency:** All repositories follow standard structure
3. **Automation:** Reduces manual work for DevSecOps team
4. **Auditability:** Full history in Git and GitHub Actions
5. **Scalability:** Can handle multiple requests efficiently
6. **Team Management:** Automatically creates and configures teams
7. **Security:** Built-in validation and approval process

## Rollback Procedure

If a repository needs to be removed after creation:

```bash
# 1. Remove from YAML files
vim data/repositories.yaml  # Remove entry
vim data/teams.yaml         # Remove 3 team entries

# 2. Commit changes
git add data/repositories.yaml data/teams.yaml
git commit -m "fix: remove repository {name}"
git push origin main

# 3. Run Terraform destroy for specific resources
terraform destroy -target='module.github_repositories["{name}"]'
terraform destroy -target='module.repository_teams["{name}-dev"]'
terraform destroy -target='module.repository_teams["{name}-test"]'
terraform destroy -target='module.repository_teams["{name}-prod"]'
```

## Next Steps

1. ✅ **Set up GitHub Environment** `repo-creation-approval`
2. ✅ **Create DevSecOps team** with appropriate members
3. ✅ **Test workflow** with sample repository request
4. ✅ **Document process** for end users
5. ✅ **Train team** on approval process
6. ✅ **Monitor** first few requests for issues
7. ✅ **Iterate** based on feedback

## Success Metrics

Track these metrics after deployment:

- Time from request to repository creation
- Number of validation failures
- Approval turnaround time
- User satisfaction with process
- Reduction in manual DevOps work

## References

- [Implementation Plan](./02-AUTOMATED_REPO_WORKFLOW_PLAN.md)
- [Project Structure Guidelines](../.github/instructions/structure.instructions.md)
- [Git Commit Conventions](../.github/instructions/git.instructions.md)
- [Technical Guidelines](../.github/instructions/tech.instructions.md)

---

**Implementation Completed By:** GitHub Copilot  
**Reviewed By:** Pending  
**Approved By:** Pending
