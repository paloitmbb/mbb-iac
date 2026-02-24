# Staging Environment

This directory contains Terraform configuration for the staging environment.

## Prerequisites

- Azure authentication configured (see [AZURE_BACKEND_SETUP.md](../../AZURE_BACKEND_SETUP.md))
- GitHub token with appropriate permissions

## Setup

```bash
# Set Azure authentication (option 1: Storage Account Access Key)
export ARM_ACCESS_KEY="your-storage-account-access-key"

# Set GitHub token
export GITHUB_TOKEN="your-github-token"

# Initialize Terraform
terraform init -backend-config=backend.tfvars

# Plan changes
terraform plan -var-file=terraform.tfvars

# Apply changes
terraform apply -var-file=terraform.tfvars
```

## Configuration

- `terraform.tfvars` - Environment-specific variable values
- `backend.tfvars` - Azure backend configuration for state management

## Backend

This environment uses Azure Blob Storage for state management:

- State file: Azure Blob Storage at `mbbtfstate/tfstate/github-staging.terraform.tfstate`
- State locking: Azure Blob Lease (automatic)

See [AZURE_BACKEND_SETUP.md](../../AZURE_BACKEND_SETUP.md) for detailed setup instructions.
