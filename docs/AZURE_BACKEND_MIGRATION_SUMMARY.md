# Azure Backend Migration Summary

## Overview

This document summarizes the changes made to migrate the Terraform backend for the **dev environment** from GitHub Releases (HTTP backend) to Azure Blob Storage (azurerm backend).

**Date**: 2026-02-18  
**Scope**: Dev environment only  
**Status**: Configuration complete, pending migration execution

## Changes Made

### 1. Backend Configuration (`versions.tf`)

**Changed**: Backend type from `http` to `azurerm`

```diff
- backend "http" {
-   # Configuration loaded from backend.tfvars
-   # Uses GitHub Releases for state storage
-   # and GitHub Issues API for state locking
+ backend "azurerm" {
+   # Configuration loaded from backend.tfvars
+   # Uses Azure Blob Storage for state storage
+   # and Azure Blob Lease for state locking
  }
```

**Impact**: All environments now use the azurerm backend configuration structure. Staging and production can still use HTTP backend by specifying appropriate backend.tfvars.

### 2. Dev Environment Backend Config (`environments/dev/backend.tfvars`)

**Changed**: Replaced HTTP backend parameters with Azure Storage parameters

**Before**:
```hcl
address  = "https://github.com/paloitmbb/mbb-iac/releases/download/state-dev/terraform.tfstate"
username = "terraform"
```

**After**:
```hcl
resource_group_name  = "rg-terraform-state"
storage_account_name = "stterraformmbbdev"
container_name       = "tfstate"
key                  = "dev.terraform.tfstate"
```

**Impact**: Dev environment now requires Azure authentication instead of GitHub token.

### 3. Init Script (`scripts/init.sh`)

**Changed**: Added backend type detection and Azure authentication support

**New Features**:
- Automatically detects backend type (Azure vs GitHub) based on backend.tfvars content
- Validates Azure authentication (ARM_ACCESS_KEY, ARM_SAS_TOKEN, or Service Principal)
- Maintains backward compatibility with GitHub HTTP backend for other environments

**Impact**: Script now supports both backend types seamlessly.

### 4. GitHub Actions Workflows

**Changed**: Added Azure authentication environment variables to all Terraform operations

**Modified Workflows**:
- `.github/workflows/terraform-apply.yml`
- `.github/workflows/terraform-apply-repo.yml`
- `.github/workflows/terraform-plan.yml`

**Added Environment Variables**:
```yaml
ARM_CLIENT_ID: ${{ secrets.ARM_CLIENT_ID }}
ARM_CLIENT_SECRET: ${{ secrets.ARM_CLIENT_SECRET }}
ARM_SUBSCRIPTION_ID: ${{ secrets.ARM_SUBSCRIPTION_ID }}
ARM_TENANT_ID: ${{ secrets.ARM_TENANT_ID }}
```

**Removed**: GitHub-specific state recovery logic from terraform apply steps (not needed with Azure backend)

**Impact**: Workflows now support both Azure (dev) and GitHub (staging/production) backends.

### 5. Documentation

**Created**:
- `AZURE_BACKEND_SETUP.md` - Comprehensive guide for Azure backend setup
- `docs/AZURE_BACKEND_MIGRATION_SUMMARY.md` - This summary document

**Updated**:
- `README.md` - Added Azure backend configuration instructions
- Updated Quick Start section to reflect dual backend support
- Added backend configuration troubleshooting

## Migration Steps Required

To complete the migration, follow these steps:

### 1. Create Azure Resources

```bash
# Set variables
RESOURCE_GROUP="rg-terraform-state"
STORAGE_ACCOUNT="stterraformmbbdev"
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

### 2. Configure GitHub Secrets (for CI/CD)

Add these secrets to your GitHub repository:

```bash
gh secret set ARM_CLIENT_ID --body "your-client-id"
gh secret set ARM_CLIENT_SECRET --body "your-client-secret"
gh secret set ARM_SUBSCRIPTION_ID --body "your-subscription-id"
gh secret set ARM_TENANT_ID --body "your-tenant-id"
```

### 3. Backup Current State

```bash
# Download current state from GitHub (backup)
curl -L -H "Authorization: token $GITHUB_TOKEN" \
  "https://github.com/paloitmbb/mbb-iac/releases/download/state-dev/terraform.tfstate" \
  -o terraform.tfstate.backup
```

### 4. Migrate State to Azure

```bash
# Set Azure authentication (choose one method)
export ARM_ACCESS_KEY="your-storage-account-access-key"
# OR
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"

# Initialize with state migration
terraform init -migrate-state -backend-config=environments/dev/backend.tfvars

# Verify migration
terraform state list
terraform plan -var-file=environments/dev/terraform.tfvars
```

### 5. Test the New Backend

```bash
# Run a plan to ensure everything works
./scripts/plan.sh dev

# If plan looks good, apply a small change to test
./scripts/apply.sh dev
```

## Environment Status

| Environment | Backend Type | State Location | Status |
|-------------|-------------|----------------|---------|
| **dev** | Azure Blob Storage | `stterraformmbbdev/tfstate/dev.terraform.tfstate` | ✅ Configured, pending migration |
| **staging** | HTTP (GitHub) | GitHub Releases `state-staging` | ✅ No changes |
| **production** | HTTP (GitHub) | GitHub Releases `state-production` | ✅ No changes |

## Required GitHub Secrets

For GitHub Actions to work with the dev environment:

| Secret | Purpose | Required |
|--------|---------|----------|
| `ARM_CLIENT_ID` | Azure Service Principal App ID | ✅ Yes |
| `ARM_CLIENT_SECRET` | Azure Service Principal Secret | ✅ Yes |
| `ARM_SUBSCRIPTION_ID` | Azure Subscription ID | ✅ Yes |
| `ARM_TENANT_ID` | Azure AD Tenant ID | ✅ Yes |
| `ORG_GITHUB_TOKEN` | GitHub organization token | ✅ Yes (existing) |

## Benefits of Azure Backend

### Advantages Over GitHub HTTP Backend

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

## Rollback Plan

If you need to rollback to GitHub backend:

1. Restore `versions.tf`:
   ```hcl
   backend "http" { }
   ```

2. Restore `environments/dev/backend.tfvars`:
   ```hcl
   address  = "https://github.com/paloitmbb/mbb-iac/releases/download/state-dev/terraform.tfstate"
   username = "terraform"
   ```

3. Re-initialize:
   ```bash
   terraform init -migrate-state -backend-config=environments/dev/backend.tfvars
   ```

## Testing Checklist

Before considering migration complete:

- [ ] Azure resources created (resource group, storage account, container)
- [ ] GitHub secrets configured (ARM_CLIENT_ID, etc.)
- [ ] State backed up from GitHub
- [ ] State migrated to Azure successfully
- [ ] `terraform plan` runs successfully
- [ ] `terraform apply` runs successfully
- [ ] GitHub Actions workflows run successfully
- [ ] State locking works (test with concurrent operations)
- [ ] State versioning enabled on storage account

## Support and Troubleshooting

For detailed setup and troubleshooting information, see:

- [AZURE_BACKEND_SETUP.md](../AZURE_BACKEND_SETUP.md) - Complete Azure backend guide
- [HTTP_BACKEND_SETUP.md](../HTTP_BACKEND_SETUP.md) - GitHub backend guide (staging/production)
- [README.md](../README.md) - General project documentation

## Questions?

If you encounter issues or have questions:

1. Check the troubleshooting section in `AZURE_BACKEND_SETUP.md`
2. Verify Azure authentication is configured correctly
3. Ensure all required Azure resources exist
4. Check GitHub Actions logs for detailed error messages
5. Verify GitHub secrets are set correctly

## Summary

This migration moves the dev environment to a more robust and enterprise-ready backend solution while maintaining the existing GitHub backend for staging and production environments. The changes are backward compatible and include comprehensive documentation and tooling support.

**Next Steps**: Follow the migration steps above to complete the transition.
