# Production Environment

This directory contains Terraform configuration for the production environment.

## Prerequisites

- GitHub token with appropriate permissions
- Release tag `state-production` must exist (create with `git tag state-production && git push origin state-production`)
- **Extra caution required**: Changes affect production resources

## Setup

```bash
# Set authentication
export GITHUB_TOKEN="your-github-token"
export TF_HTTP_PASSWORD="$GITHUB_TOKEN"

# Initialize Terraform
terraform init -backend-config=backend.tfvars

# Plan changes
terraform plan -var-file=terraform.tfvars

# Apply changes (requires confirmation)
terraform apply -var-file=terraform.tfvars
```

## Configuration

- `terraform.tfvars` - Environment-specific variable values
- `backend.tfvars` - HTTP backend configuration for state management (GitHub Releases)

## Backend

This environment uses HTTP backend with GitHub Releases for state storage:

- State file: GitHub Release asset at tag `state-production`
- State locking: GitHub Git refs API at `refs/locks/production`

See [HTTP_BACKEND_SETUP.md](../../HTTP_BACKEND_SETUP.md) for detailed setup instructions.

## ⚠️ Production Safeguards

- Always run `plan` before `apply`
- Require peer review for all changes
- Use GitHub environment protection rules
- Maintain state backups
- Changes require approval from platform team
