# Terraform Backend Configuration
# Uncomment and configure ONE of the following backend options

# =============================================================================
# Option 1: AWS S3 Backend (Recommended for AWS users)
# =============================================================================
# terraform {
#   backend "s3" {
#     bucket         = "your-terraform-state-bucket"
#     key            = "github-repos/terraform.tfstate"
#     region         = "ap-southeast-1"
#     encrypt        = true
#     dynamodb_table = "terraform-state-lock"  # For state locking
#
#     # Optional: Use assume role for cross-account access
#     # role_arn = "arn:aws:iam::ACCOUNT_ID:role/TerraformStateRole"
#   }
# }

# =============================================================================
# Option 2: Azure Blob Storage Backend
# =============================================================================
# terraform {
#   backend "azurerm" {
#     resource_group_name  = "terraform-state-rg"
#     storage_account_name = "tfstateaccount"
#     container_name       = "tfstate"
#     key                  = "github-repos/terraform.tfstate"
#
#     # Optional: Use managed identity
#     # use_msi = true
#   }
# }

# =============================================================================
# Option 3: Google Cloud Storage Backend
# =============================================================================
# terraform {
#   backend "gcs" {
#     bucket = "your-terraform-state-bucket"
#     prefix = "github-repos"
#
#     # Optional: Use specific credentials
#     # credentials = "path/to/credentials.json"
#   }
# }

# =============================================================================
# Option 4: Terraform Cloud / HCP Terraform Backend
# =============================================================================
# terraform {
#   cloud {
#     organization = "your-organization"
#
#     workspaces {
#       name = "github-repos"
#     }
#   }
# }

# =============================================================================
# Option 5: Local Backend (Default - NOT recommended for teams)
# =============================================================================
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

# =============================================================================
# SETUP INSTRUCTIONS
# =============================================================================
#
# AWS S3 Backend Setup:
# 1. Create S3 bucket with versioning enabled
# 2. Create DynamoDB table for state locking (partition key: LockID)
# 3. Configure AWS credentials (aws configure or environment variables)
# 4. Uncomment the S3 backend block above and update values
# 5. Run: terraform init -migrate-state
#
# Azure Backend Setup:
# 1. Create resource group and storage account
# 2. Create container in the storage account
# 3. Configure Azure credentials (az login or service principal)
# 4. Uncomment the azurerm backend block above and update values
# 5. Run: terraform init -migrate-state
#
# GCS Backend Setup:
# 1. Create GCS bucket with versioning enabled
# 2. Configure GCP credentials (gcloud auth or service account)
# 3. Uncomment the gcs backend block above and update values
# 4. Run: terraform init -migrate-state
#
# Terraform Cloud Setup:
# 1. Create Terraform Cloud account and organization
# 2. Create workspace
# 3. Run: terraform login
# 4. Uncomment the cloud block above and update values
# 5. Run: terraform init
