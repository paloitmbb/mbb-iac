---
applyTo: "**"
---

# Technical Guidelines

This document provides technical guidelines, coding standards, and best practices for working with the mbb-iac Terraform project.

## Technology Stack

### Core Technologies

- **Terraform**: `>= 1.14.5` - Infrastructure as Code tool
- **GitHub Provider**: `~> 6.0` - GitHub resource management
- **HCL**: HashiCorp Configuration Language for Terraform definitions
- **YAML**: Repository configuration data format
- **Shell**: Bash scripts for automation workflows

### Backend Configuration

- **Type**: HTTP backend using GitHub infrastructure
- **State Storage**: GitHub Releases (tagged state files per environment)
- **State Locking**: GitHub API (Git refs under `refs/locks/{environment}`)
- **Authentication**: `GITHUB_TOKEN` environment variable (auto-set as `TF_HTTP_PASSWORD`)

## Version Requirements

### Terraform Core

```hcl
terraform {
  required_version = ">= 1.14.5"
}
```

### Provider Versions

```hcl
required_providers {
  github = {
    source  = "integrations/github"
    version = "~> 6.0"
  }
}
```

All modules use the same version constraints to ensure consistency.

## Project Architecture

### Module Structure

The project follows a modular architecture with four core modules:

1. **github-organization** - Organization-level settings and secrets
2. **github-repository** - Repository creation and configuration
3. **github-security** - GHAS and security features (standalone, currently unused)
4. **github-copilot** - Copilot seat management and policies

### Module Versioning

All modules are **local modules** (not published to registry) and share the same version requirements as the root module. When updating versions:

1. Update `versions.tf` in the root module
2. Update `versions.tf` in each module directory
3. Run `terraform init -upgrade` to update provider lock files

### Data Flow

```
data/repositories.yaml OR environments/{env}/terraform.tfvars
                    ↓
            Root main.tf (local merging logic)
                    ↓
            Module instantiation
                    ↓
            GitHub Resources
```

**Priority**: `var.repositories` (tfvars) > YAML file

## Coding Standards

### Terraform Style

Follow official Terraform style conventions:

```hcl
# Use 2-space indentation
resource "github_repository" "this" {
  name        = var.repository_name
  description = var.description
  visibility  = var.visibility

  # Group related settings
  has_issues   = var.has_issues
  has_projects = var.has_projects
  has_wiki     = var.has_wiki

  # Use dynamic blocks for optional features
  dynamic "security_and_analysis" {
    for_each = var.enable_advanced_security ? [1] : []
    content {
      advanced_security {
        status = "enabled"
      }
    }
  }
}
```

### Variable Naming

- Use **snake_case** for all variable names
- Be descriptive and explicit (avoid abbreviations)
- Use consistent prefixes: `enable_`, `has_`, `allow_`, `default_`

```hcl
# Good
variable "enable_advanced_security" {}
variable "default_repository_permission" {}
variable "members_can_create_repositories" {}

# Avoid
variable "advSec" {}
variable "defaultRepoPerms" {}
variable "memberCreate" {}
```

### Module Variables

All module variables must include:

- **description**: Clear explanation of purpose
- **type**: Explicit type constraint
- **default**: Default value if optional
- **validation**: Input validation rules where applicable

```hcl
variable "repository_name" {
  description = "Name of the GitHub repository"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._-]+$", var.repository_name))
    error_message = "Repository name must contain only alphanumeric characters, hyphens, underscores, and periods."
  }
}
```

### YAML Configuration

Repository definitions in `data/repositories.yaml` must follow this structure:

```yaml
repositories:
  - name: repository-name # Required: alphanumeric + dashes/underscores
    description: Description # Required: brief description
    visibility: private # Required: private|public|internal
    features: # Required: repository features
      has_issues: true
      has_projects: false
      has_wiki: false
    default_branch: main # Required: default branch name
    topics: [] # Required: array of topic strings
    security: # Optional: security settings
      enable_advanced_security: false
      enable_secret_scanning: false
      enable_secret_scanning_push_protection: false
      enable_vulnerability_alerts: true
      enable_dependabot_alerts: true
      enable_dependabot_security_updates: true
    branch_protection: # Optional: branch protection rules
      pattern: main
      required_approving_review_count: 1
      require_code_owner_reviews: false
      dismiss_stale_reviews: false
      require_signed_commits: false
      enforce_admins: false
    teams: # Optional: team access
      - team: team-slug
        permission: push
    secrets: # Optional: repository secrets
      SECRET_KEY:
        description: "Secret description"
    variables: # Optional: repository variables
      VAR_KEY:
        value: "variable-value"
```

### Local Values

Use locals for:

- Complex data transformations
- File loading and parsing
- Computed values used multiple times
- Data normalization

```hcl
locals {
  repositories_file = "${path.module}/data/repositories.yaml"
  repositories_data = fileexists(local.repositories_file) ? yamldecode(file(local.repositories_file)) : { repositories = [] }

  # Normalize YAML repositories
  yaml_repositories = [
    for repo in local.repositories_data.repositories : merge(repo, {
      secrets   = try(repo.secrets, null)
      variables = try(repo.variables, null)
      security  = try(repo.security, null)
    })
  ]

  # Merge sources (tfvars takes precedence)
  all_repositories = length(var.repositories) > 0 ? var.repositories : local.yaml_repositories
}
```

## Authentication

### GitHub Token

Required permissions:

- `repo` - Full control of repositories
- `admin:org` - Full control of organizations
- `workflow` - Update GitHub Actions workflows

**Setup:**

```bash
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"
```

The `init.sh` script automatically sets `TF_HTTP_PASSWORD` from `GITHUB_TOKEN`.

### Provider Configuration

```hcl
provider "github" {
  owner = var.organization_name
  # Token read from GITHUB_TOKEN environment variable
}
```

## State Management

### Backend Setup

Each environment has dedicated backend configuration in `environments/{env}/backend.tfvars`:

```hcl
address        = "https://github.com/org/repo/releases/download/state-{env}/terraform.tfstate"
lock_address   = "https://api.github.com/repos/org/repo/git/refs/locks/{env}"
unlock_address = "https://api.github.com/repos/org/repo/git/refs/locks/{env}"
username       = "terraform"
```

### Initial Setup

Before first initialization:

```bash
# Create release tags for state storage
git tag state-dev state-staging state-production
git push origin state-dev state-staging state-production
```

### State Operations

**Always use scripts** from project root:

```bash
./scripts/init.sh [dev|staging|production]    # Initialize with backend
./scripts/plan.sh [dev|staging|production]    # Preview changes
./scripts/apply.sh [dev|staging|production]   # Apply changes
./scripts/validate.sh                         # Validate syntax
```

## Environment Management

### Environment-Specific Configuration

Each environment directory must contain:

- `terraform.tfvars` - Variable values for the environment
- `backend.tfvars` - Backend configuration for state storage
- `README.md` - Environment-specific documentation

### Variable Precedence

1. **CLI flags**: `-var` and `-var-file` flags (highest priority)
2. **Environment tfvars**: `environments/{env}/terraform.tfvars`
3. **Root tfvars**: `terraform.tfvars` (if exists)
4. **YAML data**: `data/repositories.yaml` (lowest priority)

### Switching Environments

```bash
# Initialize for specific environment
./scripts/init.sh staging

# Plan for that environment
./scripts/plan.sh staging

# Apply to that environment
./scripts/apply.sh staging
```

## Module Development

### Creating New Modules

When creating a new module:

1. **Create directory structure**:

   ```
   modules/module-name/
   ├── main.tf        # Resource definitions
   ├── variables.tf   # Input variables
   ├── outputs.tf     # Output values
   ├── versions.tf    # Version requirements
   └── README.md      # Module documentation
   ```

2. **Define version requirements** (same as root):

   ```hcl
   terraform {
     required_version = ">= 1.14.5"
     required_providers {
       github = {
         source  = "integrations/github"
         version = "~> 6.0"
       }
     }
   }
   ```

3. **Document inputs and outputs** in README.md

4. **Add module call** in root `main.tf`

### Module Best Practices

- **Single Responsibility**: Each module should manage one aspect of infrastructure
- **No Hardcoding**: Use variables for all configurable values
- **Comprehensive Outputs**: Output all useful resource attributes
- **Validation**: Add validation blocks to variables where possible
- **Dependencies**: Use `depends_on` explicitly for cross-module dependencies

```hcl
module "github_repositories" {
  source   = "./modules/github-repository"
  for_each = { for repo in local.all_repositories : repo.name => repo }

  # Pass all required variables
  repository_name = each.value.name
  description     = each.value.description
  # ...

  depends_on = [module.github_organization]
}
```

## Security Best Practices

### Secrets Management

1. **Never commit secrets** to version control
2. Use **environment variables** for tokens and API keys
3. Mark **sensitive outputs** appropriately:

   ```hcl
   output "copilot_seats" {
     description = "Copilot seat assignments"
     value       = module.github_copilot.seat_assignments
     sensitive   = true
   }
   ```

4. Store **repository secrets** encrypted in GitHub

### GHAS Configuration

When enabling GitHub Advanced Security:

```hcl
security = {
  enable_advanced_security               = true   # Requires GHAS license
  enable_secret_scanning                 = true   # Requires GHAS
  enable_secret_scanning_push_protection = true   # Requires GHAS
  enable_vulnerability_alerts            = true   # Free
  enable_dependabot_alerts               = true   # Free
  enable_dependabot_security_updates     = true   # Free
}
```

**Note**: GHAS features require organization-level license.

### State File Security

- State files stored in **private GitHub Releases**
- Access controlled via **GitHub repository permissions**
- **Never expose** state files publicly
- Use **state locking** to prevent concurrent modifications

## Testing and Validation

### Pre-Commit Checks

Before committing changes:

```bash
# Format code
terraform fmt -recursive

# Validate syntax
./scripts/validate.sh

# Check for issues
terraform validate

# Preview changes
./scripts/plan.sh dev
```

### Validation Tools

- **terraform fmt**: Auto-format HCL code
- **terraform validate**: Validate configuration syntax
- **yamllint**: Validate YAML syntax (if available)
- **tflint**: Lint Terraform code (optional)

### Testing Changes

1. **Test in dev** environment first
2. **Review plan output** carefully
3. **Apply incrementally** for large changes
4. **Verify resources** in GitHub UI
5. **Promote to staging/production** after validation

## Error Handling

### Common Issues

**1. Backend Lock Conflicts**

```bash
# If state is locked
terraform force-unlock <LOCK_ID>

# Clean approach: wait for other operations to complete
```

**2. Provider Authentication**

```bash
# Ensure token is set
echo $GITHUB_TOKEN

# Refresh token for HTTP backend
export TF_HTTP_PASSWORD="$GITHUB_TOKEN"
./scripts/init.sh dev
```

**3. State Migration**

```bash
# When changing backends
terraform init -migrate-state
```

**4. YAML Parsing Errors**

```bash
# Validate YAML syntax
python3 -c "import yaml; yaml.safe_load(open('data/repositories.yaml'))"
```

### Debugging

Enable detailed logging:

```bash
export TF_LOG=DEBUG
export TF_LOG_PATH=./terraform.log
./scripts/plan.sh dev
```

## Performance Optimization

### Parallel Operations

Terraform parallelizes resource creation by default (10 concurrent operations):

```bash
# Adjust parallelism
terraform apply -parallelism=20
```

### Large Repositories

For managing many repositories:

- Use **YAML data files** instead of inline tfvars
- Split repositories into **multiple YAML files** if needed
- Use **targeted applies** for specific repos:
  ```bash
  terraform apply -target=module.github_repositories[\"repo-name\"]
  ```

### State File Size

- Keep state file size manageable (< 10 MB)
- Consider **workspace separation** for large organizations
- Use **data sources** instead of resources where possible

## Continuous Integration

### Automation Workflow

Recommended CI/CD pipeline:

1. **On PR**: Run `terraform fmt -check`, `validate`, and `plan`
2. **On merge to main**: Auto-apply to dev environment
3. **Manual approval**: Promote to staging/production

### GitHub Actions Security

**CRITICAL GUARDRAIL**: All GitHub Actions workflows **must** use verified actions only. Using unverified or unknown third-party actions introduces supply chain risk.

#### Rules for Using GitHub Actions

1. **Use only verified actions**: Only use actions from:
   - GitHub's official `actions/` organization
   - Verified/trusted publishers (e.g., `hashicorp/`, `aws-actions/`, `azure/`)
   - Avoid unknown or unverified third-party actions

2. **Keep actions up-to-date**: Regularly review and update action versions when new releases are available, especially for security patches. Use tools like [Dependabot](https://docs.github.com/en/code-security/dependabot) to automate this.

### GitHub Actions Example

```yaml
name: Terraform

on:
  pull_request:
    paths:
      - "**.tf"
      - "**.tfvars"
      - "data/**.yaml"

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      # ✅ Verified action from actions/
      - uses: actions/checkout@v4

      # ✅ Verified action from hashicorp/
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.14.5

      - name: Terraform Init
        run: ./scripts/init.sh dev
        env:
          GITHUB_TOKEN: ${{ secrets.GH_TOKEN }}

      - name: Terraform Validate
        run: terraform validate

      - name: Terraform Plan
        run: ./scripts/plan.sh dev
        env:
          GITHUB_TOKEN: ${{ secrets.GH_TOKEN }}
```

## Outputs and Reporting

### Available Outputs

The root module provides these outputs:

- `organization_name` - GitHub organization name
- `repository_source` - Source of repo config ("yaml" or "tfvars")
- `repository_count` - Total number of managed repositories
- `repositories` - Map of repository details (name, URL, SSH URL)
- `copilot_seats` - Copilot seat assignments (sensitive)

### Querying Outputs

```bash
# View all outputs
terraform output

# View specific output
terraform output repository_count

# Output as JSON
terraform output -json repositories | jq
```

## Documentation Standards

### Module Documentation

Each module README.md must include:

1. **Purpose**: What the module manages
2. **Requirements**: Provider versions and prerequisites
3. **Usage**: Example module calls
4. **Inputs**: Table of all variables
5. **Outputs**: Table of all outputs
6. **Resources**: List of managed resources

### Code Comments

```hcl
# High-level block comments for complex logic
# Explain WHY, not WHAT

# Load repositories from YAML data file
locals {
  repositories_file = "${path.module}/data/repositories.yaml"

  # Merge repositories from YAML file and tfvars (tfvars takes precedence)
  all_repositories = length(var.repositories) > 0 ? var.repositories : local.yaml_repositories
}
```

### Inline Documentation

Use Terraform's native documentation features:

```hcl
variable "example" {
  description = <<-EOT
    Detailed description of the variable.
    Can span multiple lines.
    Supports markdown formatting.
  EOT
  type    = string
  default = "default-value"
}
```

## Troubleshooting Guide

### Quick Diagnostics

```bash
# Check Terraform version
terraform version

# Check provider versions
terraform version -json | jq '.provider_selections'

# Validate configuration
terraform validate

# Check state
terraform show

# List resources
terraform state list

# Inspect specific resource
terraform state show 'module.github_repositories["repo-name"].github_repository.this'
```

### Resource Import

To import existing GitHub repositories:

```bash
# Use the import script
./scripts/import-repos.sh

# Or manually import
terraform import 'module.github_repositories["existing-repo"].github_repository.this' existing-repo
```

### State Cleanup

```bash
# Remove resource from state (does not delete from GitHub)
terraform state rm 'module.github_repositories["old-repo"].github_repository.this'

# Move resource in state
terraform state mv 'module.old["repo"]' 'module.new["repo"]'
```

## Migration and Upgrades

### Upgrading Terraform Version

1. **Update version requirements** in `versions.tf` (root and all modules)
2. **Update lock file**: `terraform init -upgrade`
3. **Test in dev** environment
4. **Review changelog** for breaking changes
5. **Update CI/CD pipelines**

### Upgrading GitHub Provider

1. **Update provider version** in `versions.tf`
2. **Run**: `terraform init -upgrade`
3. **Review provider changelog** for breaking changes
4. **Test thoroughly** in dev environment
5. **Check deprecation warnings** in plan output

### Migrating to New Backend

```bash
# Update backend configuration
vim environments/dev/backend.tfvars

# Re-initialize with new backend
terraform init -migrate-state

# Verify state was migrated
terraform plan
```

## Best Practices Summary

### DO

✅ Use scripts for all Terraform operations  
✅ Test changes in dev environment first  
✅ Review plan output before applying  
✅ Keep modules focused and reusable  
✅ Document all variables and outputs  
✅ Use YAML for managing many repositories  
✅ Version control all configuration  
✅ Follow conventional commit messages  
✅ Use state locking for concurrent safety  
✅ Keep secrets in environment variables  
✅ Use only verified GitHub Actions from trusted publishers

### DON'T

❌ Commit secrets or tokens to Git  
❌ Apply changes without reviewing plan  
❌ Skip dev environment testing  
❌ Hardcode values in modules  
❌ Bypass validation checks  
❌ Modify state files manually  
❌ Use deprecated provider features  
❌ Share state files publicly  
❌ Skip backend initialization  
❌ Ignore provider version constraints  
❌ Use unverified or unknown third-party GitHub Actions

## Additional Resources

- [Terraform Documentation](https://www.terraform.io/docs)
- [GitHub Provider Documentation](https://registry.terraform.io/providers/integrations/github/latest/docs)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
- [HTTP Backend Documentation](https://www.terraform.io/docs/language/settings/backends/http.html)
- [Project README](../README.md)
- [HTTP Backend Setup Guide](../HTTP_BACKEND_SETUP.md)
- [Data Directory Documentation](../data/README.md)
