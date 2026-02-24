# Azure Backend Migration Summary

## Overview

This document summarizes the changes made to migrate the Terraform backend for all environments from GitHub Releases (HTTP backend) to Azure Blob Storage (azurerm backend).

**Date**: 2026-02-18
**Scope**: All environments (dev, staging, production)
**Status**: Configuration complete

## Changes Made

### 1. Backend Configuration (`versions.tf`)

**Changed**: Backend type to `azurerm`

```hcl
backend "azurerm" {
  # Configuration loaded from backend.tfvars
  # Uses Azure Blob Storage for state storage
  # and Azure Blob Lease for state locking
}
```

**Impact**: All environments use the azurerm backend configuration structure.

### 2. Environment Backend Configs (`environments/{env}/backend.tfvars`)

**Changed**: All environments now use Azure Storage parameters

```hcl
resource_group_name  = "mbb"
storage_account_name = "mbbtfstate"
container_name       = "tfstate"
key                  = "github.terraform.tfstate"  # unique key per environment
```

**Impact**: All environments require Azure authentication.

### 3. Init Script (`scripts/init.sh`)

**Changed**: Simplified to Azure-only backend support

**New Features**:
- Validates Azure authentication (ARM_ACCESS_KEY, ARM_SAS_TOKEN, or Service Principal)
- Uses Azure Blob Storage backend for all environments

**Impact**: Script now supports Azure backend authentication seamlessly.

### 4. GitHub Actions Workflows

**Changed**: Implemented OIDC authentication for Azure with `azure/login@v2` action

**Modified Workflows**:
- `.github/workflows/terraform-apply.yml`
- `.github/workflows/terraform-apply-repo.yml`
- `.github/workflows/terraform-plan.yml`

**Added**:
- `id-token: write` permission for OIDC token generation
- `azure/login@v2` step for secretless authentication
- `ARM_USE_OIDC: true` environment variable

**Environment Variables** (using OIDC):
```yaml
ARM_CLIENT_ID: ${{ secrets.ARM_CLIENT_ID }}
ARM_SUBSCRIPTION_ID: ${{ secrets.ARM_SUBSCRIPTION_ID }}
ARM_TENANT_ID: ${{ secrets.ARM_TENANT_ID }}
ARM_USE_OIDC: true
```

**Removed**:
- `ARM_CLIENT_SECRET` - No longer needed with OIDC
- GitHub-specific state recovery logic from terraform apply steps

**Impact**: Workflows now use secretless OIDC authentication for Azure across all environments (dev, staging, production).

### 5. Documentation

**Created**:
- `AZURE_BACKEND_SETUP.md` - Comprehensive guide for Azure backend setup
- `docs/AZURE_BACKEND_MIGRATION_SUMMARY.md` - This summary document

**Updated**:
- `README.md` - Updated to reflect Azure-only backend configuration
- Updated Quick Start section to reflect unified Azure backend support
- Added backend configuration troubleshooting

## Migration Steps Required

To complete the migration, follow these steps:

### 1. Create Azure Resources

```bash
# Set variables
RESOURCE_GROUP="mbb"
STORAGE_ACCOUNT="mbbtfstate"
CONTAINER_NAME="tfstate"
LOCATION="eastus"

# Login to Azure
az login

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create storage account
az storage account create \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS \
  --encryption-services blob \
  --kind StorageV2

# Create blob container
az storage container create \
  --name $CONTAINER_NAME \
  --account-name $STORAGE_ACCOUNT
```

### 2. Configure GitHub Secrets and OIDC (for CI/CD)

#### Step 2a: Setup OIDC Federated Credentials in Azure

```bash
GITHUB_ORG="paloitmbb"
GITHUB_REPO="mbb-iac"
APP_NAME="github-actions-oidc"

# Create Azure AD application and service principal
az ad app create --display-name $APP_NAME
APP_ID=$(az ad app list --display-name $APP_NAME --query '[0].appId' -o tsv)
az ad sp create --id $APP_ID

# Create federated credentials for GitHub Actions
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-actions-main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'$GITHUB_ORG'/'$GITHUB_REPO':ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'

az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-actions-pr",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'$GITHUB_ORG'/'$GITHUB_REPO':pull_request",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Assign Storage Blob Data Contributor role
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
az role assignment create \
  --assignee $APP_ID \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/mbb"
```

#### Step 2b: Configure GitHub Secrets

Add these secrets to your GitHub repository (note: no client secret needed):

```bash
gh secret set ARM_CLIENT_ID --body "$APP_ID"
gh secret set ARM_SUBSCRIPTION_ID --body "$SUBSCRIPTION_ID"
gh secret set ARM_TENANT_ID --body "$(az account show --query tenantId -o tsv)"
```

### 3. Migrate State to Azure

```bash
# Set Azure authentication (for local migration)
# Option 1: Using Azure CLI
az login

# Option 2: Using Storage Account Access Key
export ARM_ACCESS_KEY="your-storage-account-access-key"

# Initialize with state migration
terraform init -migrate-state -backend-config=environments/dev/backend.tfvars

# Verify migration
terraform state list
terraform plan -var-file=environments/dev/terraform.tfvars
```

**Note**: GitHub Actions will use OIDC authentication automatically (no secrets needed).

### 4. Test the New Backend

```bash
# Run a plan to ensure everything works
./scripts/plan.sh dev

# If plan looks good, apply a small change to test
./scripts/apply.sh dev
```

## Environment Status

| Environment | Backend Type | State Location | Status |
|-------------|-------------|----------------|---------|
| **dev** | Azure Blob Storage | `mbbtfstate/tfstate/github.terraform.tfstate` | ✅ Configured |
| **staging** | Azure Blob Storage | `mbbtfstate/tfstate/github-staging.terraform.tfstate` | ✅ Configured |
| **production** | Azure Blob Storage | `mbbtfstate/tfstate/github-production.terraform.tfstate` | ✅ Configured |

## Required GitHub Secrets

For GitHub Actions OIDC authentication with Azure (all environments):

| Secret | Purpose | Required |
|--------|---------|----------|
| `ARM_CLIENT_ID` | Azure Service Principal App ID | ✅ Yes |
| `ARM_SUBSCRIPTION_ID` | Azure Subscription ID | ✅ Yes |
| `ARM_TENANT_ID` | Azure AD Tenant ID | ✅ Yes |
| `ORG_GITHUB_TOKEN` | GitHub organization token | ✅ Yes (existing) |

**Note**: `ARM_CLIENT_SECRET` is NOT required when using OIDC authentication.

## Benefits of Azure Backend

### Advantages of Azure Backend

1. **Native State Locking**: Automatic locking via Azure Blob Lease (no manual implementation needed)
2. **Better Performance**: Faster state read/write operations
3. **Enterprise Features**: Built-in versioning, soft delete, and encryption
4. **Reliability**: Azure's enterprise SLA and redundancy options
5. **Security**: Fine-grained RBAC with Azure AD integration
6. **Cost**: Minimal cost (~$0.10/month for typical usage)

### What We Gained

- ✅ Reliable state locking (prevents concurrent modifications)
- ✅ State versioning and recovery (blob versioning)
- ✅ Better security controls (Azure RBAC)
- ✅ Audit logging (Azure Monitor)
- ✅ Faster state operations
- ✅ No more manual state recovery logic in workflows

## Testing Checklist

Before considering migration complete:

- [ ] Azure resources created (resource group, storage account, container)
- [ ] GitHub secrets configured (ARM_CLIENT_ID, etc.)
- [ ] State migrated to Azure successfully
- [ ] `terraform plan` runs successfully
- [ ] `terraform apply` runs successfully
- [ ] GitHub Actions workflows run successfully
- [ ] State locking works (test with concurrent operations)
- [ ] State versioning enabled on storage account

## Support and Troubleshooting

For detailed setup and troubleshooting information, see:

- [AZURE_BACKEND_SETUP.md](../AZURE_BACKEND_SETUP.md) - Complete Azure backend guide
- [README.md](../README.md) - General project documentation

## Questions?

If you encounter issues or have questions:

1. Check the troubleshooting section in `AZURE_BACKEND_SETUP.md`
2. Verify Azure authentication is configured correctly
3. Ensure all required Azure resources exist
4. Check GitHub Actions logs for detailed error messages
5. Verify GitHub secrets are set correctly

## Summary

All environments (dev, staging, production) use Azure Blob Storage as the Terraform backend. This provides a consistent, enterprise-ready solution with native state locking, versioning, and RBAC-based access control.
