# Automated Repository Workflow - Implementation Summary

**Date:** 12 February 2026  
**Status:** ✅ Implementation Complete (Updated - Team Access Model)

## What Was Implemented

This implementation creates an issue-driven automated workflow for repository creation with access granted to existing organization teams, following the plan in [02-AUTOMATED_REPO_WORKFLOW_PLAN.md](./02-AUTOMATED_REPO_WORKFLOW_PLAN.md).

**Key Design Decisions:**

1. **No Team Creation:** Users specify existing organization teams that should have access
2. **Simplified Form:** Only essential information requested; other settings use defaults
3. **Team Validation:** All specified teams must exist in the organization before approval
4. **Centralized Defaults:** Repository settings use default values from `data/defaults.yaml`

## Files Modified

### 1. GitHub Issue Template

**File:** `.github/ISSUE_TEMPLATE/new-repository.yml`

**Updated with:**

- ✅ Team Access field (comma-separated existing team slugs)
- ✅ Removed Team Maintainers field (not needed)
- ✅ Updated descriptions to clarify existing teams only
- ✅ Updated acknowledgment checkboxes

### 2. GitHub Workflow

**File:** `.github/workflows/repo-request.yml`

**Updated with:**

- ✅ Team existence validation using GitHub API
- ✅ Parse teams from comma-separated input
- ✅ Validate all teams exist in organization
- ✅ Update repositories.yaml with team access configuration
- ✅ Removed team creation steps
- ✅ Updated success/failure messages

### 3. Data Files

**Location:** `data/`

- ✅ `defaults.yaml` - Default repository configuration for automated workflow
- ✅ `repositories.yaml` - Updated by workflow with team access configuration

**Note:** No `teams.yaml` file needed - teams are not created by the workflow.

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

**Repository Structure with Teams:**

```yaml
repositories:
  - name: mbb-payment-service
    description: "Payment processing service"
    visibility: private
    features:
      has_issues: true
      has_projects: true
      has_wiki: false
    default_branch: main
    topics:
      - payment
      - api
    teams:
      - team: platform-team
        permission: admin
      - team: backend-developers
        permission: push
```

## Existing Module Leveraged

**Module:** `modules/github-repository/`

The existing repository module already supports team access via the `teams` parameter:

```hcl
resource "github_team_repository" "this" {
  for_each = {
    for team in var.teams : team.team => team
  }

  team_id    = each.value.team
  repository = github_repository.this.name
  permission = each.value.permission
}
```

**No new modules created** - leverages existing functionality.

## Issue Template Updates

**Updated form with essential fields:**

- ✅ Repository name (required)
- ✅ **Team Access** (required - comma-separated existing team slugs)
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

**Changed from original plan:**

- ❌ Team Maintainers field **replaced with** Team Access field
- ❌ No team creation - uses existing organization teams only

**Removed fields (now use defaults):**

- ❌ Repository description (auto-generated)
- ❌ Visibility selection (uses default: private)
- ❌ Target environment selection (uses default)
- ❌ Feature checkboxes (uses defaults)
- ❌ Security feature checkboxes (uses defaults)
- ❌ Topics input (uses defaults + tech stack)
- ❌ Branch protection settings (uses defaults)
- ❌ Additional notes (not needed)

## GitHub Actions Workflow

**File:** `.github/workflows/repo-request.yml`

Implemented workflow with team validation:

**Job 1: Validation (validate-request)**

- ✅ Parse issue body to extract fields (name, teams, tech stack, justification, default branch)
- ✅ Load default values from `defaults.yaml`
- ✅ Validate repository name format (lowercase, hyphens only)
- ✅ **Validate teams exist in organization using GitHub API**
- ✅ Check repository doesn't already exist in GitHub
- ✅ **Check repository doesn't already exist in data/repositories.yaml** (NEW)
- ✅ Post validation results comment to issue
- ✅ Add validation status labels
- ✅ Close issue if validation fails

**Job 2: Creation (create-repository)**

- ✅ Requires approval via GitHub Environment
- ✅ Merge issue form data with default values from defaults.yaml
- ✅ Generate description from repository name and tech stack
- ✅ Update `repositories.yaml` with new repository including team access configuration
- ✅ **Parse comma-separated teams and add to repository configuration**
- ✅ Create feature branch with YAML changes
- ✅ Create pull request for review
- ✅ Post success/failure comment to issue
- ✅ Link issue to PR (closes when PR merged)

## Terraform Configuration Status

✅ **Validation:** All Terraform files validated successfully
✅ **Format:** All Terraform files formatted
✅ **Modules:** All modules initialized
✅ **Syntax:** No syntax errors

```
terraform validate
Success! The configuration is valid.
```

## Team Access Model

**Existing Teams Only:** Repositories are granted access to existing organization teams specified in the request.

**Supported Permissions:**

| Permission | Description                                     |
| ---------- | ----------------------------------------------- |
| `pull`     | Read access - can pull but not push             |
| `triage`   | Can manage issues and PRs without write access  |
| `push`     | Write access - can push to repository (default) |
| `maintain` | Maintain access - can manage repo without admin |
| `admin`    | Full administrative access                      |

**Default Permission:** If not specified in the YAML, teams are granted `push` (write) permission.

**Team Management:** Users must create and manage teams separately through GitHub UI or API. The workflow only grants access to existing teams.

## What Still Needs to Be Done

### 1. GitHub Environment Setup (Manual)

⚠️ **Required before workflow can run:**

1. Go to repository **Settings → Environments**
2. Create new environment: `repo-creation-approval`
3. Add required reviewers: `paloitmbb-devsecops` team
4. Set deployment branch pattern: `main`

**Why:** The workflow requires manual approval from DevSecOps team before creating the pull request.

### 2. Create DevSecOps Team (Manual)

1. Go to Organization → Teams
2. Create team: `paloitmbb-devsecops`
3. Add team members who should approve requests

### 3. Create Organization Teams (Manual)

**Before users can request repositories:**

1. Create teams in the organization that will be used for repository access
2. Examples: `platform-team`, `backend-developers`, `qa-team`, etc.
3. Users will reference these team slugs in repository requests

### 4. Configure GitHub Token (Manual)

⚠️ **Required for all workflows:**

1. Create a GitHub Personal Access Token (classic) with scopes:
   - `repo` - Full control of private repositories
   - `read:org` - Read org and team membership
   - `admin:org` - Full control of orgs and teams
2. Add as repository secret: `ORG_GITHUB_TOKEN`
3. This token is used for:
   - Team existence validation in repo-request workflow
   - Terraform operations (provider authentication)
   - HTTP backend state management

### 4. Test the Workflow

After environment and team setup:

1. **Create a test issue** using the new template
2. **Fill in all required fields** including existing team slugs
3. **Wait for validation comment** (should validate teams exist)
4. **Approve the workflow** (if validation passed)
5. **Wait for PR creation** automatically
6. **Review and merge the PR** with YAML changes
7. **Run terraform apply** in the environment
8. **Check repository creation**
9. **Verify teams have access** to the repository
10. **Verify team permissions** are correct
11. **Verify issue closed** after successful creation

### 6. Documentation Updates

Consider updating:

- Main README.md with team access workflow usage instructions
- CONTRIBUTING.md with repository request process
- Add troubleshooting section for common team validation issues
- Document team management and access procedures

## Architecture Flow

```
User Creates Issue (Simplified Form)
   - Repository name
   - Team access (existing teams)
   - Tech stack
   - Justification
   - Default branch
       ↓
Validation Job (automatic)
   ✅ Validate name
   ✅ Validate teams exist in org
   ✅ Check repository existence in GitHub
   ✅ Check repository existence in YAML
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
   ✅ Update repositories.yaml with teams
   ✅ Create feature branch
   ✅ Create Pull Request
   ✅ Post success to issue
   ✅ Link issue to PR
       ↓
PR Review & Merge (manual)
   ⏳ DevSecOps reviews YAML changes
   ✅ Merges PR to main
       ↓
Terraform Apply (manual)
   ✅ Run terraform apply
   ✅ Repository created
   ✅ Team access granted
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

## Security Considerations

✅ **Input Validation:** All user inputs validated before processing
✅ **Approval Required:** DevSecOps team must approve before creation
✅ **Team Validation:** Team existence validated against organization
✅ **Repository Checks:** Ensures no duplicate repositories in both GitHub and YAML
✅ **YAML Duplicate Prevention:** Validates repository name doesn't exist in data/repositories.yaml
✅ **Audit Trail:** All changes committed to Git history
✅ **Least Privilege:** Workflow uses minimum required permissions

## Benefits

1. **Self-Service:** Users can request repositories via simple form
2. **Consistency:** All repositories follow standard structure and defaults
3. **Automation:** Reduces manual work for DevSecOps team
4. **Auditability:** Full history in Git and GitHub Actions
5. **Scalability:** Can handle multiple requests efficiently
6. **Team Access Control:** Uses existing teams, no new team proliferation
7. **Security:** Built-in validation and approval process
8. **Team Validation:** Prevents typos and non-existent team references
9. **Simplified Management:** No team creation/deletion needed in workflow
10. **Flexibility:** Teams can be managed independently of repositories
11. **Duplicate Prevention:** Validates against both GitHub and YAML to prevent conflicts

## Rollback Procedure

If a repository needs to be removed after creation:

**Option A: Via Git (Recommended)**

```bash
# 1. Remove from YAML file
vim data/repositories.yaml  # Remove repository entry

# 2. Create PR with changes
git checkout -b remove-repo-{name}
git add data/repositories.yaml
git commit -m "fix: 🗑️ remove repository {name}"
git push origin remove-repo-{name}
# Create PR and merge after review

# 3. Run Terraform apply to remove repository
./scripts/apply.sh <environment>
```

**Option B: Manual Terraform Destroy**

```bash
# 1. Remove from YAML file
vim data/repositories.yaml  # Remove entry

# 2. Create PR and merge changes
# (same as Option A)

# 3. Run Terraform destroy for specific resource
terraform destroy -target='module.github_repositories["{name}"]'
```

**Note:** Team access is automatically removed when the repository is destroyed. No separate team cleanup needed.

## Next Steps

1. ✅ **Set up GitHub Environment** `repo-creation-approval`
2. ✅ **Create DevSecOps team** with appropriate members
3. ✅ **Create organization teams** for repository access (platform-team, developers, qa-team, etc.)
4. ✅ **Test workflow** with sample repository request using existing teams
5. ✅ **Document process** for end users with list of available teams
6. ✅ **Train team** on approval process and team validation
7. ✅ **Monitor** first few requests for issues
8. ✅ **Iterate** based on feedback

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
