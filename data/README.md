# Data Directory

This directory contains external data sources that can be loaded by Terraform, providing an alternative to defining all configurations in `.tfvars` files.

## Purpose

The data directory allows you to:

1. **Separate repository definitions** from Terraform variable files
2. **Manage large numbers of repositories** more easily in YAML format
3. **Version control repository configurations** independently
4. **Reduce clutter** in environment-specific tfvars files

## Files

### repositories.yaml

Contains repository definitions in YAML format. This file is loaded automatically by the root module if it exists.

**Structure:**

```yaml
repositories:
  - name: repository-name
    description: Repository description
    visibility: private|public|internal
    features:
      has_issues: true|false
      has_projects: true|false
      has_wiki: true|false
    default_branch: main
    topics:
      - topic1
      - topic2
    security:
      enable_vulnerability_alerts: true|false
      enable_advanced_security: true|false
      enable_secret_scanning: true|false
      enable_secret_scanning_push_protection: true|false
      enable_dependabot_alerts: true|false
      enable_dependabot_security_updates: true|false
    branch_protection:
      pattern: main
      required_approving_review_count: 2
      require_code_owner_reviews: true|false
      dismiss_stale_reviews: true|false
      require_signed_commits: true|false
      enforce_admins: true|false
    teams:
      - team: team-name
        permission: pull|push|admin|maintain|triage
```

## How It Works

The root `main.tf` includes logic to:

1. Check if `data/repositories.yaml` exists
2. Load and parse the YAML file if present
3. Use YAML repositories if `var.repositories` is empty
4. Use `var.repositories` from tfvars if provided (takes precedence)

```hcl
locals {
  repositories_file = "${path.module}/data/repositories.yaml"
  repositories_data = fileexists(local.repositories_file) ? yamldecode(file(local.repositories_file)) : { repositories = [] }

  # Merge repositories from YAML file and tfvars (tfvars takes precedence)
  yaml_repositories = local.repositories_data.repositories
  all_repositories  = length(var.repositories) > 0 ? var.repositories : local.yaml_repositories
}
```

## Usage

### Option 1: Use YAML File (Recommended for many repositories)

1. Define repositories in `data/repositories.yaml`
2. Leave `repositories = []` in your environment tfvars files
3. Terraform will automatically load from YAML

### Option 2: Use Tfvars (Traditional approach)

1. Define repositories in `environments/{env}/terraform.tfvars`
2. YAML file is ignored if tfvars has repositories defined

### Option 3: Hybrid Approach

You can maintain both files and switch between them as needed by setting or clearing the `repositories` variable in tfvars.

## Benefits

### For Large Organizations

- Easier to manage 50+ repositories
- Better for bulk operations and templates
- Can use YAML anchors for common patterns

### For Version Control

- Cleaner diffs when adding/removing repositories
- Easier to review changes in YAML format
- Can separate repository config from environment config

### For Teams

- Non-Terraform users can understand YAML more easily
- Can generate YAML from other systems/scripts
- Simpler onboarding for new team members

## Example

See [repositories.yaml](./repositories.yaml) for a complete example with three sample repositories:

- `mbb-web-portal` - Frontend web application
- `mbb-api-gateway` - Backend API gateway
- `mbb-mobile-app` - Mobile application

## Validation

To validate your YAML file:

```bash
# Check YAML syntax
yamllint data/repositories.yaml

# Validate Terraform can parse it
terraform console
> yamldecode(file("data/repositories.yaml"))

# Run Terraform validate
terraform validate
```

## Notes

- YAML file is optional - tfvars approach still works
- If both exist, tfvars takes precedence
- Schema must match the Terraform variable type definition
