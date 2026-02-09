# Development Environment

This directory contains Terraform configuration for the development environment.

## Prerequisites

- GitHub token with appropriate permissions
- Release tag `state-dev` must exist (create with `git tag state-dev && git push origin state-dev`)

## Setup

```bash
# Set authentication
export GITHUB_TOKEN="your-github-token"
export TF_HTTP_PASSWORD="$GITHUB_TOKEN"

# Initialize Terraform
terraform init -backend-config=backend.tfvars

# Plan changes
terraform plan -var-file=terraform.tfvars

# Apply changes
terraform apply -var-file=terraform.tfvars
```

## Configuration

- `terraform.tfvars` - Environment-specific variable values
- `backend.tfvars` - HTTP backend configuration for state management (GitHub Releases)

## Backend

This environment uses HTTP backend with GitHub Releases for state storage:

- State file: GitHub Release asset at tag `state-dev`
- State locking: GitHub Git refs API at `refs/locks/dev`

See [HTTP_BACKEND_SETUP.md](../../HTTP_BACKEND_SETUP.md) for detailed setup instructions.
