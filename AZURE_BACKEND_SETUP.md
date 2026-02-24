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

### Method 2: OIDC (OpenID Connect) - Recommended for CI/CD

OIDC provides secretless authentication for GitHub Actions workflows.

#### Setup OIDC Federated Credentials

```bash
# Get your GitHub repository information
GITHUB_ORG="paloitmbb"
GITHUB_REPO="mbb-iac"
APP_NAME="github-actions-oidc"

# Create an Azure AD application
az ad app create --display-name $APP_NAME

# Get the application ID
APP_ID=$(az ad app list --display-name $APP_NAME --query '[0].appId' -o tsv)

# Create a service principal
az ad sp create --id $APP_ID

# Get the service principal object ID
SP_OBJECT_ID=$(az ad sp list --display-name $APP_NAME --query '[0].id' -o tsv)

# Create federated credential for main branch
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-actions-main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'$GITHUB_ORG'/'$GITHUB_REPO':ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Create federated credential for pull requests
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-actions-pr",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'$GITHUB_ORG'/'$GITHUB_REPO':pull_request",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Assign appropriate roles
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
az role assignment create \
  --assignee $APP_ID \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/mbb"
```

### Method 3: Service Principal with Client Secret (Legacy)

**Note**: This method is deprecated for GitHub Actions. Use OIDC instead.

```bash
# Create a service principal (for local development only)
az ad sp create-for-rbac --name "terraform-backend-sp" --role Contributor

# Set environment variables
export ARM_CLIENT_ID="<appId>"
export ARM_CLIENT_SECRET="<password>"
export ARM_SUBSCRIPTION_ID="<subscriptionId>"
export ARM_TENANT_ID="<tenant>"
```

### Method 4: Managed Identity (For Azure VMs/Containers)

When running Terraform from Azure resources (VMs, Container Instances, etc.), you can use Managed Identity without any credentials.

### Method 5: Azure CLI (For Local Development)

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

## GitHub Actions Setup with OIDC

### Required Secrets

For GitHub Actions workflows using OIDC authentication, configure these secrets:

1. **ARM_CLIENT_ID**: Service Principal Application ID
2. **ARM_SUBSCRIPTION_ID**: Azure Subscription ID
3. **ARM_TENANT_ID**: Azure Active Directory Tenant ID

**Note**: `ARM_CLIENT_SECRET` is NOT required when using OIDC authentication.

### Setting Secrets

```bash
# Using GitHub CLI
gh secret set ARM_CLIENT_ID --body "your-client-id"
gh secret set ARM_SUBSCRIPTION_ID --body "your-subscription-id"
gh secret set ARM_TENANT_ID --body "your-tenant-id"
```

Or via GitHub UI:
1. Navigate to Repository Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Add each secret listed above

### How OIDC Works

The GitHub Actions workflows use the `azure/login@v2` action with OIDC:

```yaml
- name: Azure Login with OIDC
  uses: azure/login@v2
  with:
    client-id: ${{ secrets.ARM_CLIENT_ID }}
    tenant-id: ${{ secrets.ARM_TENANT_ID }}
    subscription-id: ${{ secrets.ARM_SUBSCRIPTION_ID }}
```

This provides:
- ✅ **Secretless authentication** - No client secrets to manage
- ✅ **Short-lived tokens** - Automatically rotated
- ✅ **Enhanced security** - Reduces secret sprawl
- ✅ **Audit trail** - Better tracking of authentication events

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

## Additional Resources

- [Terraform Azure Backend Documentation](https://www.terraform.io/docs/language/settings/backends/azurerm.html)
- [Azure Storage Documentation](https://docs.microsoft.com/en-us/azure/storage/)
- [Azure Authentication Methods](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs#authenticating-to-azure)
- [Azure RBAC Documentation](https://docs.microsoft.com/en-us/azure/role-based-access-control/)
