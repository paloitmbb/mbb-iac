terraform {
  required_version = ">= 1.5.7"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }

  # Uncomment when repo is pushed to GitHub and releases are created
  # backend "http" {
  #   # Configuration loaded from backend.tfvars
  #   # Uses GitHub Releases for state storage
  #   # and GitHub Issues API for state locking
  # }
}

provider "github" {
  owner = var.organization_name
  # Authentication via GITHUB_TOKEN environment variable
  # or GitHub App installation
}
