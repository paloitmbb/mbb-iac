# Repository Configuration Examples

This document provides examples of how to configure repositories using both the YAML data file and the traditional tfvars approach.

## Approach Comparison

### YAML Data File Approach

**Pros:**

- Easier to read and edit for non-Terraform users
- Better for managing many repositories (50+)
- Cleaner version control diffs
- Can use YAML features like anchors for common patterns
- Separates data from environment configuration

**Cons:**

- Requires understanding of YAML syntax
- Less type safety (validated at runtime)
- Need to ensure YAML structure matches Terraform schema

**When to use:**

- Managing 10+ repositories
- Team includes non-Terraform users
- Want to separate repository configs from environment settings
- Need to generate configurations from other systems

### Tfvars File Approach

**Pros:**

- Native Terraform syntax
- Type checking and validation
- All configuration in one place
- Familiar to Terraform users

**Cons:**

- Can become very large with many repositories
- Harder to read/edit for non-Terraform users
- More verbose syntax

**When to use:**

- Managing fewer than 10 repositories
- Team is comfortable with HCL syntax
- Want all configuration in environment-specific files
- Need strong type checking

## Side-by-Side Example

### Same Repository Defined Both Ways

#### YAML Format (`data/repositories.yaml`)

```yaml
repositories:
  - name: customer-api
    description: Customer management REST API
    visibility: private
    features:
      has_issues: true
      has_projects: true
      has_wiki: false
    default_branch: main
    topics:
      - api
      - nodejs
      - microservices
    security:
      enable_vulnerability_alerts: true
      enable_advanced_security: true
      enable_secret_scanning: true
      enable_secret_scanning_push_protection: true
      enable_dependabot_alerts: true
      enable_dependabot_security_updates: true
    branch_protection:
      pattern: main
      required_approving_review_count: 2
      require_code_owner_reviews: true
      dismiss_stale_reviews: true
      require_signed_commits: false
      enforce_admins: false
    teams:
      - team: engineering
        permission: push
      - team: platform
        permission: admin
    secrets:
      DATABASE_URL:
        description: Database connection string
      API_KEY:
        description: Third-party API key
    variables:
      LOG_LEVEL:
        value: info
      MAX_CONNECTIONS:
        value: "100"
```

#### HCL Format (`environments/dev/terraform.tfvars`)

```hcl
repositories = [
  {
    name        = "customer-api"
    description = "Customer management REST API"
    visibility  = "private"

    features = {
      has_issues   = true
      has_projects = true
      has_wiki     = false
    }

    default_branch = "main"

    topics = ["api", "nodejs", "microservices"]

    security = {
      enable_vulnerability_alerts            = true
      enable_advanced_security               = true
      enable_secret_scanning                 = true
      enable_secret_scanning_push_protection = true
      enable_dependabot_alerts               = true
      enable_dependabot_security_updates     = true
    }

    branch_protection = {
      pattern                         = "main"
      required_approving_review_count = 2
      require_code_owner_reviews      = true
      dismiss_stale_reviews           = true
      require_signed_commits          = false
      enforce_admins                  = false
    }

    teams = [
      {
        team       = "engineering"
        permission = "push"
      },
      {
        team       = "platform"
        permission = "admin"
      }
    ]

    secrets = {
      DATABASE_URL = {
        description = "Database connection string"
      }
      API_KEY = {
        description = "Third-party API key"
      }
    }

    variables = {
      LOG_LEVEL = {
        value = "info"
      }
      MAX_CONNECTIONS = {
        value = "100"
      }
    }
  }
]
```

## Using YAML Anchors for Common Patterns

YAML supports anchors and aliases to avoid repetition:

```yaml
# Define common configurations as anchors
x-common-security: &common-security
  enable_vulnerability_alerts: true
  enable_advanced_security: true
  enable_secret_scanning: true
  enable_secret_scanning_push_protection: true
  enable_dependabot_alerts: true
  enable_dependabot_security_updates: true

x-common-branch-protection: &common-branch-protection
  pattern: main
  required_approving_review_count: 2
  require_code_owner_reviews: true
  dismiss_stale_reviews: true
  require_signed_commits: false
  enforce_admins: false

x-common-features: &common-features
  has_issues: true
  has_projects: true
  has_wiki: false

repositories:
  - name: service-a
    description: Service A
    visibility: private
    features: *common-features
    default_branch: main
    topics: [backend, nodejs]
    security: *common-security
    branch_protection: *common-branch-protection
    teams:
      - team: engineering
        permission: push

  - name: service-b
    description: Service B
    visibility: private
    features: *common-features
    default_branch: main
    topics: [backend, python]
    security: *common-security
    branch_protection: *common-branch-protection
    teams:
      - team: engineering
        permission: push

  - name: service-c
    description: Service C
    visibility: private
    features: *common-features
    default_branch: main
    topics: [backend, golang]
    security: *common-security
    branch_protection: *common-branch-protection
    teams:
      - team: engineering
        permission: push
```

## Switching Between Approaches

### Using YAML (Default)

1. Ensure `data/repositories.yaml` contains your repository definitions
2. In your environment tfvars, set: `repositories = []`
3. Run terraform plan/apply

### Using Tfvars

1. Define repositories in `environments/{env}/terraform.tfvars`
2. The YAML file will be automatically ignored
3. Run terraform plan/apply

## Validation

### Validate YAML Syntax

```bash
# Using yamllint
yamllint data/repositories.yaml

# Using Python
python3 -c "import yaml; yaml.safe_load(open('data/repositories.yaml'))"

# Using yq
yq eval data/repositories.yaml
```

### Test Terraform Parsing

```bash
terraform console
> yamldecode(file("data/repositories.yaml"))
```

### Validate Configuration

```bash
terraform validate
terraform plan
```

## Migration Guide

### From Tfvars to YAML

1. Copy repository definitions from tfvars
2. Convert HCL syntax to YAML
3. Save to `data/repositories.yaml`
4. Set `repositories = []` in tfvars
5. Run `terraform plan` to verify no changes
6. Commit both files

### From YAML to Tfvars

1. Copy repository definitions from YAML
2. Convert YAML to HCL syntax
3. Add to `repositories` array in tfvars
4. Run `terraform plan` to verify no changes
5. Optionally remove YAML file
6. Commit changes

## Best Practices

1. **Choose one approach per environment** - Don't mix YAML and tfvars for the same environment
2. **Use YAML anchors** - Reduce duplication with anchors and aliases
3. **Validate before committing** - Always run `terraform validate` and `terraform plan`
4. **Document your choice** - Add comments explaining which approach is used
5. **Keep schemas in sync** - Ensure YAML structure matches Terraform variable types
6. **Use consistent formatting** - Run yamllint or terraform fmt regularly
7. **Version control both** - Keep both approaches in git for flexibility

## Troubleshooting

### Error: "Insufficient features blocks"

**Cause:** YAML structure doesn't match Terraform schema

**Solution:** Ensure all required fields are present:

```yaml
features:
  has_issues: true
  has_projects: true
  has_wiki: false
```

### Error: "Invalid repository name"

**Cause:** Repository name contains invalid characters

**Solution:** Use only lowercase letters, numbers, and hyphens

### No repositories created

**Cause:** Both tfvars and YAML have empty repository lists

**Solution:** Define repositories in either file, not both

### Changes not detected

**Cause:** Tfvars takes precedence over YAML

**Solution:** If using YAML, ensure `repositories = []` in tfvars
