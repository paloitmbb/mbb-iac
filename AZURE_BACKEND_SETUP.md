# Azure Storage Backend Setup Guide

This project uses Azure Blob Storage as the backend for Terraform state storage (for the **dev** environment).

## How It Works

### State Storage

- Terraform state files are stored in Azure Blob Storage
- Each environment can have its own storage container or blob
- State is retrieved and updated via Azure Storage API
- Built-in versioning and soft delete capabilities

### State Locking

- State locking is implemented using Azure Blob Lease
- This prevents concurrent Terraform operations automatically
- Locks are managed natively by Terraform without additional configuration

## Prerequisites

### 1. Azure Resources

You need the following Azure resources created before using this backend:

- **Resource Group**: Container for your Azure resources
- **Storage Account**: Azure Storage Account for storing state files
- **Blob Container**: Container within the storage account

### 2. Create Azure Resources

You can create these resources using Azure CLI, Azure Portal, or Terraform itself.

#### Using Azure CLI

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

#### Using Azure Portal

1. Navigate to [Azure Portal](https://portal.azure.com)
2. Create a new Resource Group (e.g., `mbb`)
3. Create a new Storage Account (e.g., `mbbtfstate`)
   - Performance: Standard
   - Replication: LRS (Locally Redundant Storage)
   - Enable blob soft delete (recommended)
4. Create a new Container named `tfstate` in the storage account

## Authentication Methods

Azure Terraform provider supports multiple authentication methods:

### Method 1: Storage Account Access Key (Simplest)

```bash
# Get the storage account key
export ARM_ACCESS_KEY=$(az storage account keys list \
  --resource-group mbb \
  --account-name mbbtfstate \
  --query '[0].value' -o tsv)
```

### Method 2: Service Principal (Recommended for CI/CD)

```bash
# Create a service principal
az ad sp create-for-rbac --name "terraform-backend-sp" --role Contributor

# Set environment variables
export ARM_CLIENT_ID="<appId>"
export ARM_CLIENT_SECRET="<password>"
export ARM_SUBSCRIPTION_ID="<subscriptionId>"
export ARM_TENANT_ID="<tenant>"
```

### Method 3: Managed Identity (For Azure VMs/Containers)

When running Terraform from Azure resources (VMs, Container Instances, etc.), you can use Managed Identity without any credentials.

### Method 4: Azure CLI (For Local Development)

```bash
# Login to Azure CLI
az login

# Terraform will automatically use Azure CLI credentials
```

## Backend Configuration

The dev environment backend is configured in `environments/dev/backend.tfvars`:

```hcl
resource_group_name  = "mbb"
storage_account_name = "mbbtfstate"
container_name       = "tfstate"
key                  = "github.terraform.tfstate"
```

## GitHub Actions Setup

### Required Secrets

For GitHub Actions workflows, configure these secrets in your repository:

1. **ARM_CLIENT_ID**: Service Principal Application ID
2. **ARM_CLIENT_SECRET**: Service Principal Password/Secret
3. **ARM_SUBSCRIPTION_ID**: Azure Subscription ID
4. **ARM_TENANT_ID**: Azure Active Directory Tenant ID

### Setting Secrets

```bash
# Using GitHub CLI
gh secret set ARM_CLIENT_ID --body "your-client-id"
gh secret set ARM_CLIENT_SECRET --body "your-client-secret"
gh secret set ARM_SUBSCRIPTION_ID --body "your-subscription-id"
gh secret set ARM_TENANT_ID --body "your-tenant-id"
```

Or via GitHub UI:
1. Navigate to Repository Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Add each secret listed above

## Local Development Setup

### Option 1: Using Storage Account Key

```bash
export ARM_ACCESS_KEY="your-storage-account-access-key"
./scripts/init.sh dev
```

### Option 2: Using Service Principal

```bash
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"
./scripts/init.sh dev
```

### Option 3: Using Azure CLI

```bash
az login
./scripts/init.sh dev
```

## State Operations

### Initializing Terraform

```bash
./scripts/init.sh dev
```

The first time you run this, Terraform will:
1. Connect to Azure Storage Account
2. Create or retrieve the state file from the blob container
3. Enable state locking via blob lease

### Viewing State

```bash
# Using Azure CLI
az storage blob download \
  --account-name mbbtfstate \
  --container-name tfstate \
  --name github.terraform.tfstate \
  --file terraform.tfstate

# Or use Terraform
terraform show
```

### State Backup and Versioning

Azure Blob Storage provides built-in versioning and soft delete:

```bash
# Enable versioning on the storage account
az storage account blob-service-properties update \
  --account-name mbbtfstate \
  --enable-versioning true

# Enable soft delete (30 days retention)
az storage account blob-service-properties update \
  --account-name mbbtfstate \
  --enable-delete-retention true \
  --delete-retention-days 30
```

## Advantages

✅ **Native Locking**: Built-in state locking with Azure Blob Lease  
✅ **Versioning**: Native blob versioning and soft delete  
✅ **Security**: Fine-grained access control with Azure RBAC  
✅ **Reliability**: Enterprise-grade storage with SLA  
✅ **Performance**: Fast state operations  
✅ **Cost-Effective**: Low storage costs  
✅ **Encryption**: Automatic encryption at rest and in transit

## Security Best Practices

1. **Access Keys**
   - Rotate storage account keys regularly
   - Use Azure Key Vault for storing keys
   - Prefer Service Principal or Managed Identity over access keys

2. **Network Security**
   - Enable firewall rules on storage account
   - Use private endpoints for enhanced security
   - Restrict access to specific IP ranges or VNets

3. **RBAC**
   - Grant minimum required permissions
   - Use Azure AD groups for team access
   - Enable Azure AD authentication for storage

4. **Audit and Monitoring**
   - Enable storage account logging
   - Monitor access with Azure Monitor
   - Set up alerts for unauthorized access

5. **Backup**
   - Enable soft delete and versioning
   - Implement backup policies
   - Test disaster recovery procedures

## Troubleshooting

### Error: "Unable to list provider registration status"

**Cause**: Missing Azure authentication  
**Solution**: Ensure one of the authentication methods is configured

```bash
# Check if authenticated
az account show
```

### Error: "Storage account not found"

**Cause**: Storage account doesn't exist or wrong name  
**Solution**: Verify storage account exists

```bash
az storage account show --name mbbtfstate --resource-group mbb
```

### Error: "Failed to get existing workspaces"

**Cause**: Container doesn't exist  
**Solution**: Create the container

```bash
az storage container create --name tfstate --account-name mbbtfstate
```

### Error: "Failed to lock state"

**Cause**: State is already locked by another process  
**Solution**: Wait for other operations to complete or force unlock (use with caution)

```bash
terraform force-unlock <lock-id>
```

### Error: "Authorization failed"

**Cause**: Insufficient permissions  
**Solution**: Grant proper permissions to the service principal

```bash
# Grant Storage Blob Data Contributor role
az role assignment create \
  --assignee <service-principal-id> \
  --role "Storage Blob Data Contributor" \
  --scope /subscriptions/<subscription-id>/resourceGroups/mbb
```

## Migration from GitHub Backend

If migrating from the GitHub HTTP backend:

### 1. Backup Current State

```bash
# Download current state from GitHub
curl -L -H "Authorization: token $GITHUB_TOKEN" \
  "https://github.com/paloitmbb/mbb-iac/releases/download/state-dev/terraform.tfstate" \
  -o terraform.tfstate.backup
```

### 2. Update Configuration

The backend configuration has already been updated in:
- `versions.tf` - Changed backend from `http` to `azurerm`
- `environments/dev/backend.tfvars` - Azure Storage configuration

### 3. Initialize with State Migration

```bash
# Set Azure authentication
export ARM_ACCESS_KEY="your-access-key"
# OR use az login

# Initialize with state migration
terraform init -migrate-state -backend-config=environments/dev/backend.tfvars
```

### 4. Verify Migration

```bash
# Verify state
terraform state list

# Run a plan to ensure everything works
./scripts/plan.sh dev
```

## Cost Considerations

Azure Blob Storage costs are minimal for Terraform state:

- **Storage**: ~$0.02 per GB/month (LRS)
- **Operations**: Minimal cost for read/write operations
- **Expected Monthly Cost**: < $1 for typical usage

Example: A 10MB state file with 100 operations/month ≈ $0.10/month

## Additional Resources

- [Terraform Azure Backend Documentation](https://www.terraform.io/docs/language/settings/backends/azurerm.html)
- [Azure Storage Documentation](https://docs.microsoft.com/en-us/azure/storage/)
- [Azure Authentication Methods](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs#authenticating-to-azure)
- [Azure RBAC Documentation](https://docs.microsoft.com/en-us/azure/role-based-access-control/)
