# Azure Storage Backend
# State storage: Azure Blob Storage
# State locking: Azure Blob Lease

# Azure Storage Account configuration
# These values should be set via environment variables:
# - ARM_ACCESS_KEY or ARM_SAS_TOKEN for authentication
# - Or use Azure CLI / Managed Identity authentication

resource_group_name  = "mbb"
storage_account_name = "mbbtfstate"
container_name       = "tfstate"
key                  = "github-staging.terraform.tfstate"
