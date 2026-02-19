# Quick Start: Using the Data Directory

## TL;DR

**To use YAML for repository management:**

1. Edit [repositories.yaml](./repositories.yaml) to add/modify repositories
2. In your environment tfvars (`environments/{env}/terraform.tfvars`), ensure: `repositories = []`
3. Run: `terraform plan` to preview changes
4. Run: `terraform apply` to create repositories

**To use traditional tfvars:**

1. Define repositories in `environments/{env}/terraform.tfvars`
2. YAML file will be automatically ignored
3. Run terraform commands as usual

## Current Repository Count

The [repositories.yaml](./repositories.yaml) file currently contains **3 sample repositories**:

1. `mbb-web-portal` - Frontend web application
2. `mbb-api-gateway` - Backend API gateway
3. `mbb-mobile-app` - Mobile application

## Quick Commands

```bash
# Preview what will be created from YAML
terraform console
> local.yaml_repositories

# Check which source is being used
terraform console
> length(var.repositories) > 0 ? "tfvars" : "yaml"

# Validate YAML syntax
yamllint data/repositories.yaml

# Count repositories in YAML
yq eval '.repositories | length' data/repositories.yaml

# List repository names in YAML
yq eval '.repositories[].name' data/repositories.yaml
```

## File Structure

```
data/
├── README.md           # Full documentation
├── EXAMPLES.md         # Detailed examples and comparisons
├── QUICK_START.md      # This file - quick reference
└── repositories.yaml   # Repository definitions
```

## Common Tasks

### Add a New Repository

Edit `repositories.yaml` and add:

```yaml
- name: new-repo-name
  description: Repository description
  visibility: private
  features:
    has_issues: true
    has_projects: true
    has_wiki: false
  default_branch: main
  topics: []
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
  teams: []
```

### Remove a Repository

1. Find the repository in `repositories.yaml`
2. Delete the entire repository block
3. Run `terraform plan` to see the removal
4. Run `terraform apply` to delete (⚠️ destructive!)

### Modify Repository Settings

1. Locate the repository in `repositories.yaml`
2. Update the desired fields
3. Run `terraform plan` to preview changes
4. Run `terraform apply` to update

### Copy a Repository Configuration

Use YAML anchors or simply copy-paste and modify the name and description.

## When to Use This Approach

✅ **Use YAML when:**

- Managing 10+ repositories
- Team includes non-Terraform users
- Want cleaner version control
- Need to generate configs programmatically

❌ **Use tfvars when:**

- Managing < 10 repositories
- Team is Terraform-savvy only
- Want all config in one place
- Need maximum type safety

## Next Steps

- Read [README.md](./README.md) for detailed documentation
- See [EXAMPLES.md](./EXAMPLES.md) for complete examples
- View [repositories.yaml](./repositories.yaml) for sample repositories

## Need Help?

- **Syntax errors**: Run `yamllint data/repositories.yaml`
- **Schema issues**: Check [EXAMPLES.md](./EXAMPLES.md) for correct structure
- **Terraform errors**: Run `terraform validate` and check error messages
- **Not working**: Verify `repositories = []` in your environment's tfvars file
