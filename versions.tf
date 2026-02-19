terraform {
  required_version = ">= 1.5.7"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }

  backend "azurerm" {
    # Configuration loaded from backend.tfvars
    # Uses Azure Blob Storage for state storage
    # and Azure Blob Lease for state locking
  }
}

provider "github" {
  owner = var.organization_name
  # Authentication via GITHUB_TOKEN environment variable
  # or GitHub App installation
}
