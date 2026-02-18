# Azure Storage Backend
# State storage: Azure Blob Storage
# State locking: Azure Blob Lease

# Azure Storage Account configuration
# These values should be set via environment variables:
# - ARM_ACCESS_KEY or ARM_SAS_TOKEN for authentication
# - Or use Azure CLI / Managed Identity authentication

resource_group_name  = "rg-terraform-state"
storage_account_name = "stterraformmbbdev"
container_name       = "tfstate"
key                  = "dev.terraform.tfstate"
