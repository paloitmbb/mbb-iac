# mbb-iac: GitHub Organization Infrastructure as Code

Terraform project for managing GitHub organization settings, repositories, teams, GHAS, and Copilot configurations.

## Quick Reference

**Key Files & Locations**:
- `data/repositories.yaml` - Repository definitions (YAML-driven, never hardcode in .tf files)
- `data/teams.yaml` - Team definitions
- `data/defaults.yaml` - Default settings for all repositories
- `.github/ISSUE_TEMPLATE/new-repository.yml` - Repository request form template
- `.github/workflows/repo-creation.yml` - Automated repository request workflow
- `.github/workflows/terraform-apply-repo.yml` - Auto-apply after repo-request PR merge
- `scripts/init.sh` - Initialize Terraform (auto-sets backend auth from GITHUB_TOKEN)
- `scripts/plan.sh` - Preview changes (requires environment: dev/staging/production)
- `scripts/apply.sh` - Apply changes (requires environment: dev/staging/production)

**Critical Secrets**:
- `GITHUB_TOKEN` - Required for local Terraform operations (auto-exported as TF_HTTP_PASSWORD)
- `ORG_GITHUB_TOKEN` - Required for workflows (needs `repo` + `read:org` scopes)

**Must-Know Patterns**:
- ✅ Always use wrapper scripts (`./scripts/init.sh dev`), never raw `terraform` commands
- ✅ Repository definitions in YAML only, never in `.tf` files
- ✅ Team slugs must be lowercase with hyphens (not underscores)
- ✅ GitHub environment `repo-creation-approval` must exist for repository request automation
- ❌ Never commit without validating YAML syntax first (`./scripts/validate.sh`)

## Project Structure

```
mbb-iac/
├── main.tf                    # Root module orchestration
├── data/
│   ├── repositories.yaml      # Repository definitions (YAML-driven)
│   ├── teams.yaml            # Team definitions
│   └── defaults.yaml         # Default settings
├── modules/
│   ├── github-organization/   # Org settings
│   ├── github-repository/     # Repository management
│   ├── github-security/       # GHAS configuration
│   ├── github-teams/          # Team management
│   └── github-copilot/        # Copilot seat assignments
├── environments/
│   ├── dev/                  # Development environment
│   ├── staging/              # Staging environment
│   └── production/           # Production environment
└── scripts/
    ├── init.sh               # Initialize Terraform
    ├── plan.sh               # Preview changes
    ├── apply.sh              # Apply changes
    └── validate.sh           # Validate syntax
```

## Critical Pattern: YAML-Driven Configuration

**Never hardcode resources in `.tf` files**. Always use YAML definitions in `data/`:

### Repository Management

**data/repositories.yaml**:
```yaml
repositories:
  - name: my-repo
    description: Repository description
    visibility: private
    features:
      has_issues: true
      has_wiki: false
    default_branch: main
    topics:
      - backend
      - nodejs
    security:
      enable_vulnerability_alerts: true
      enable_advanced_security: false  # Requires GHAS license
      enable_dependabot_alerts: true
    variables:
      ENVIRONMENT:
        value: production
```

**Loaded in Terraform**:
```hcl
locals {
  repositories = yamldecode(file("${path.module}/data/repositories.yaml")).repositories
}

module "repositories" {
  source   = "./modules/github-repository"
  for_each = { for repo in local.repositories : repo.name => repo }

  name        = each.value.name
  description = each.value.description
  # ... other attributes
}
```

**Default Values** (`data/defaults.yaml`):
- Provides default configuration for all repositories
- Merged with repository-specific settings
- Includes features, security, branch protection defaults
- Reduces repetition in repositories.yaml

## Automated Repository Request Feature

**Self-service repository creation** via GitHub Issues:

1. **Create Issue** using template: `.github/ISSUE_TEMPLATE/new-repository.yml`
   - Title format: `[REPO REQUEST] <repository-name>`
   - Form fields: Repository name, tech stack, teams (optional), justification, default branch
2. **Automated Validation** (`repo-creation.yml` workflow):
   - **Job 1: validate-request**:
     - Parses issue form using `parse-issue-form` composite action
     - Loads defaults from `data/defaults.yaml` using `load-repository-defaults`
     - Validates repo name pattern (lowercase, hyphens only)
     - Validates team existence in organization (optional field)
     - Checks for repository duplicates
     - Posts validation results using `notify-issue-status` action
   - **Job 2: create-repository-pr** (requires `repo-creation-approval` environment):
     - Updates `data/repositories.yaml` using `update-yaml-config` action
     - Creates PR using `create-config-pull-request` action with auto-generated commit message
     - Links PR to original issue (`Closes #<issue-number>`)
3. **Review & Approval**: DevSecOps team reviews PR
4. **Auto-Apply**: `terraform-apply-repo.yml` workflow:
   - Triggers on PR merge with `repo-request` label
   - Runs `terraform apply` to create repository in GitHub
   - Updates issue with repository URL and access details
   - Closes linked issue automatically
5. **Notification**: Issue comment with repository details and team access confirmation

**Key Features**:
- **Optional team access**: Teams field can be omitted; repository created without team access
- **Modular workflow**: Uses 6 composite actions from mbb-tf-actions for maintainability
- **Environment protection**: Requires manual approval via GitHub environment
- **Automatic defaults**: All unspecified settings use values from `data/defaults.yaml`
- **Tech stack topics**: Automatically adds tech stack as repository topic

**See**: [docs/HOW_TO_REQUEST_REPOSITORY.md](docs/HOW_TO_REQUEST_REPOSITORY.md)

**Workflow Files**:
- `.github/workflows/repo-creation.yml` - Issue-based repository request automation
- `.github/workflows/terraform-apply-repo.yml` - Apply Terraform after repo-request PR is merged
- `.github/ISSUE_TEMPLATE/new-repository.yml` - GitHub issue form template

**Composite Actions Used** (from mbb-tf-actions):
- `parse-issue-form` - Parse GitHub issue form fields with regex field extraction
- `load-repository-defaults` - Load default configuration from `defaults.yaml`
- `validate-repository-request` - Validate repository name, team existence, and duplicates
- `notify-issue-status` - Post validation results to issue with labels
- `update-yaml-config` - Update `repositories.yaml` with new repository entry
- `create-config-pull-request` - Create PR with proper branch management

**Required Secrets**:
- `ORG_GITHUB_TOKEN` - For creating PRs and accessing organization teams (requires `read:org` + `repo` scopes)

## Two Deployment Methods

### Method 1: GitHub Actions CI/CD (Recommended)

**Automated workflows** handle validation, security scanning, and deployment:

**1. Repository Request Workflow** (`.github/workflows/repo-creation.yml`):
- **Trigger**: Issue opened with title `[REPO REQUEST]`
- **Actions**: Uses 6 modular composite actions from mbb-tf-actions
- **Flow**: Parse → Validate → Notify → Update YAML → Create PR
- **Environment**: Requires `repo-creation-approval` environment for PR creation
- **See**: [docs/HOW_TO_REQUEST_REPOSITORY.md](docs/HOW_TO_REQUEST_REPOSITORY.md) for user guide

**2. Terraform Apply Repository** (`.github/workflows/terraform-apply-repo.yml`):
- **Trigger**: PR closed (merged) with `repo-request` label
- **Actions**: Applies Terraform to create repository
- **Flow**: Extract issue → Check PR → Init → Apply → Notify issue → Close issue
- **Result**: Repository created in GitHub with team access granted

**3. Terraform CI Workflow** (`.github/workflows/terraform-ci.yml`):
- **Trigger**: PR or push to feature branches
- **Actions**: Uses `terraform-gh-ci.yml` reusable workflow from mbb-tf-workflows
- **Security**: Parallel tfsec + Trivy scanning → SARIF upload to GitHub Security
- **Output**: Plan posted as PR comment
- **Secrets**: Requires `ORG_GITHUB_TOKEN`

**4. Terraform Plan Workflow** (`.github/workflows/terraform-plan.yml`):
- **Trigger**: Pull requests
- **Actions**: Simple validation and plan preview
- **Flow**: Validate YAML syntax → terraform plan → PR comment
- **Use case**: Quick PR validation without full CI/CD

**5. Terraform Apply Workflow** (`.github/workflows/terraform-apply.yml`):
- **Trigger**: Push to `main` branch (excludes repo-request commits)
- **Actions**: Auto-applies Terraform changes
- **Environment**: Defaults to `dev`, configurable via workflow_dispatch
- **Skip logic**: Skips if commit message contains "repo-request" or "add repository"

**Typical Workflow Pattern**:
1. **For new repository**: Create `[REPO REQUEST]` issue → Auto-PR → Review → Merge → Auto-apply
2. **For configuration changes**: Edit YAML → Push → terraform-ci.yml runs → Review plan → Merge → terraform-apply.yml runs

### Method 2: Local Development with Wrapper Scripts

**For direct Terraform execution** (testing, debugging, emergency fixes):

```bash
# ❌ DON'T DO THIS
terraform init
terraform plan
terraform apply

# ✅ DO THIS
./scripts/init.sh dev
./scripts/plan.sh dev
./scripts/apply.sh dev
```

**Why Wrapper Scripts?**
1. **Automatic backend authentication**: Sets `TF_HTTP_PASSWORD` from `GITHUB_TOKEN`
2. **Environment-specific configuration**: Loads correct backend and tfvars
3. **Safety checks**: Validates files exist before running
4. **Consistent usage**: Enforces explicit environment selection

**Script Usage**:
```bash
# Initialize Terraform (required first)
./scripts/init.sh dev|staging|production

# Validate Terraform syntax
./scripts/validate.sh

# Preview changes
./scripts/plan.sh dev|staging|production

# Apply changes
./scripts/apply.sh dev|staging|production
```

## Backend: GitHub HTTP Backend

State is stored in **GitHub Releases**, not Azure:

```hcl
# environments/dev/backend.tfvars
address        = "https://github.com/org/mbb-iac/releases/download/state-dev/terraform.tfstate"
lock_address   = "https://api.github.com/repos/org/mbb-iac/git/refs/locks/dev"
unlock_address = "https://api.github.com/repos/org/mbb-iac/git/refs/locks/dev"
username       = "terraform"
# password via TF_HTTP_PASSWORD (from GITHUB_TOKEN)
```

### Authentication Flow

```bash
export GITHUB_TOKEN="ghp_xxx"    # Set token
./scripts/init.sh dev            # Auto-exports TF_HTTP_PASSWORD
```

The `init.sh` script automatically:
1. Checks for `GITHUB_TOKEN`
2. Exports as `TF_HTTP_PASSWORD`
3. Runs `terraform init` with backend config

## Module Architecture

### github-repository (Per-Repository Module)

**Called via for_each**:
```hcl
module "repositories" {
  source   = "./modules/github-repository"
  for_each = { for repo in local.repositories : repo.name => repo }

  name       = each.value.name
  visibility = each.value.visibility
  # ...
}
```

**Key Pattern**: One module instance per repository definition.

### github-security (Security Settings)

Manages:
- GitHub Advanced Security (GHAS)
- Secret scanning
- Push protection
- Dependabot alerts

**Prerequisite**: Organization must have GHAS licenses available.

### github-teams (Team Management)

**data/teams.yaml**:
```yaml
teams:
  - name: platform-team
    description: Platform engineering team
    privacy: closed
    members:
      - username: johndoe
        role: maintainer
```

**Critical**: Team slugs must be **lowercase with hyphens** (not underscores).

### github-copilot (Copilot Management)

Assigns Copilot seats to users based on team membership or individual grants.

## Common Tasks

### Add New Repository

**Option A: Automated (Recommended)**
1. Create GitHub issue with title: `[REPO REQUEST] my-new-repo`
2. Fill out issue template (`.github/ISSUE_TEMPLATE/new-repository.yml`):
   - **Repository Name**: Lowercase with hyphens (e.g., `mbb-payment-api`)
   - **Team Access** (Optional): Comma-separated team slugs (e.g., `platform-team, backend-devs`)
   - **Tech Stack**: Dropdown selection (React, Java Springboot, NodeJS, Python, Others)
   - **Business Justification**: Why the repository is needed
   - **Default Branch**: main, master, or develop
3. Submit and wait for automated validation
4. Review PR created by workflow
5. Approve and merge PR
6. Repository automatically created by `terraform-apply-repo.yml`

**Validation checks performed**:
- Repository name matches pattern `^[a-z0-9-]+$`
- Teams exist in organization (queries GitHub API)
- Repository doesn't already exist
- If validation fails: Issue closed with error details

**Option B: Manual (Direct YAML Edit)**
1. **Edit YAML**:
   ```bash
   vim data/repositories.yaml
   # Add repository definition
   ```

2. **Validate**:
   ```bash
   ./scripts/validate.sh
   ```

3. **Preview**:
   ```bash
   ./scripts/plan.sh dev
   ```

4. **Apply**:
   ```bash
   ./scripts/apply.sh dev
   ```

### Import Existing Repository

```bash
terraform import 'module.repositories["repo-name"].github_repository.this' org-name/repo-name
```

**Critical**: Use **single quotes** around module path to prevent shell expansion.

### Enable GHAS for Repository

1. Update `data/repositories.yaml`:
   ```yaml
   security:
     enable_advanced_security: true
     enable_secret_scanning: true
     enable_secret_scanning_push_protection: true
   ```

2. Ensure org has GHAS licenses
3. Run plan and apply

### Modify Team Membership

1. Edit `data/teams.yaml`
2. Add/remove members
3. Run plan and apply

## Environment-Specific Configuration

### Three Environments

- **dev**: Development/testing changes
- **staging**: Pre-production validation
- **production**: Live organization settings

### Environment Files

Each environment has:
```
environments/{env}/
├── backend.tfvars      # Backend configuration
└── terraform.tfvars    # Environment-specific variables
```

### State Files

Separate state per environment:
- `state-dev`
- `state-staging`
- `state-production`

Stored as GitHub Releases in this repository.

### GitHub Environment Protection

**Critical**: The `repo-creation-approval` environment must exist in GitHub repository settings:
- **Purpose**: Gates PR creation in repo-creation workflow (Job 2)
- **Reviewers**: Add `paloitmbb-devsecops` team as required reviewers
- **Settings**: Repository Settings → Environments → Create `repo-creation-approval`
- **Effect**: Manual approval required before workflow creates PR for new repository

Without this environment configured, Job 2 of `repo-creation.yml` will fail.

## Important Gotchas

### Authentication
- ✅ **Must** export `GITHUB_TOKEN` before running scripts
- ❌ Scripts fail without token (can't access HTTP backend)
- ✅ Token needs: `repo`, `admin:org`, `workflow` scopes

### YAML Validation
- ❌ YAML syntax errors **break Terraform**
- ✅ Validate YAML before planning (use `./scripts/validate.sh`)
- ✅ Use YAML linters in editor

### GHAS Licensing
- ❌ Enabling GHAS without licenses fails
- ✅ Check org license availability first
- ✅ GHAS seats are limited per organization

### Module Paths in Import
- ❌ `module.repositories[repo-name]` - Shell expands brackets
- ✅ `'module.repositories["repo-name"]'` - Single quotes prevent expansion

### Team Slugs
- ❌ `platform_team` - Underscores not allowed
- ✅ `platform-team` - Use hyphens
- ✅ Must be lowercase

### State Management
- State stored in **GitHub** (not Azure like mbb-tf-actions/workflows)
- Uses HTTP backend (not Azure blob storage)
- Different authentication mechanism (GITHUB_TOKEN, not OIDC)

## Development Workflow

### Automated CI/CD Flow (Recommended)

Typical workflow using GitHub Actions:

```bash
# 1. Create feature branch OR use issue-based repo request
git checkout -b feat/add-new-repo
# OR: Create issue with [REPO REQUEST] title

# 2. Edit YAML definitions (if not using automated repo request)
vim data/repositories.yaml

# 3. Commit and push
git add .
git commit -m "feat: add new repository"
git push origin feat/add-new-repo

# 4. Open pull request
# - terraform-plan.yml validates changes
# - terraform-ci.yml runs security scans
# - Plan output posted as PR comment

# 5. Review plan output and security findings

# 6. Merge to main
# - terraform-apply.yml auto-applies changes
# - Repository created in GitHub
```

### Local Development Flow

For testing, debugging, or emergency fixes:

```bash
# 1. Create feature branch
git checkout -b feat/add-new-repo

# 2. Edit YAML definitions
vim data/repositories.yaml

# 3. Validate syntax
./scripts/validate.sh

# 4. Initialize (if needed)
./scripts/init.sh dev

# 5. Preview changes
./scripts/plan.sh dev

# 6. Review plan output carefully

# 7. Apply changes
./scripts/apply.sh dev

# 8. Test in dev, then promote to staging/production
./scripts/plan.sh staging
./scripts/apply.sh staging
```

## This vs Other Projects

**mbb-iac** (this project): GitHub organization management
- Manages: GitHub resources (repos, teams, GHAS)
- Backend: GitHub HTTP backend
- Auth: GITHUB_TOKEN
- Workflow: Wrapper scripts

**mbb-tf-actions/workflows/caller1**: Azure Terraform CI/CD
- Manages: Azure infrastructure
- Backend: Azure Blob Storage
- Auth: OIDC (Workload Identity Federation)
- Workflow: GitHub Actions

**Key Difference**: Different cloud providers, different authentication, different backends.

## Related Documentation

- See [workspace .github/copilot-instructions.md](../../.github/copilot-instructions.md) for mono-repo overview
- See [data/README.md](data/README.md) for YAML structure details
- See [HTTP_BACKEND_SETUP.md](HTTP_BACKEND_SETUP.md) for backend configuration
