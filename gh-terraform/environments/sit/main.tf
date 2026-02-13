# SIT Environment Configuration
# System Integration Testing environment for GitHub repository management

terraform {
  required_version = ">= 1.14.0"

  required_providers {
    github = {
      source  = "integrations/github"
      version = ">= 6.10"
    }
  }

  # Backend configuration - uncomment and configure for your infrastructure
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "github-repos/sit/terraform.tfstate"
  #   region         = "ap-southeast-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

# GitHub Provider Configuration
provider "github" {
  owner = var.organization
  token = var.github_token
}

# Load repositories from YAML data file
locals {
  yaml_data = yamldecode(file("${path.module}/../../data/repositories.yaml"))
  all_repos = try(local.yaml_data.repositories, {})
  repositories = {
    for name, repo in local.all_repos : name => repo
    if try(repo.environment, "all") == "sit" || try(repo.environment, "all") == "all"
  }
}

# GitHub Repository Module
module "github_repos" {
  source = "../../modules/github-repo"

  repositories   = local.repositories
  default_topics = var.default_topics
}

# Load organizations from YAML data file
locals {
  org_yaml_data = yamldecode(file("${path.module}/../../data/organizations.yaml"))
  all_orgs      = try(local.org_yaml_data.organizations, {})
  organizations = {
    for name, org in local.all_orgs : name => org
    if(try(org.environment, "all") == "sit" || try(org.environment, "all") == "all") && var.enterprise_slug != ""
  }
}

# GitHub Enterprise Organization Module — only runs when enterprise_slug is provided
module "github_orgs" {
  source = "../../modules/github-org"
  count  = var.enterprise_slug != "" ? 1 : 0

  organizations   = local.organizations
  enterprise_slug = var.enterprise_slug
}

# Load archive requests from YAML data file
# Filter by organization so only repos belonging to the current provider org are processed
locals {
  archive_yaml_data    = yamldecode(file("${path.module}/../../data/archive-requests.yaml"))
  all_archive_requests = try(local.archive_yaml_data.archive_requests, {})
  archive_requests = {
    for name, req in local.all_archive_requests : name => req
    if try(req.organization, "") == var.organization
  }
}

# GitHub Archive Repository Module — archives repos via data source validation
module "github_archive_repos" {
  source = "../../modules/github-archive-repo"

  github_token     = var.github_token
  archive_requests = local.archive_requests
}

# Load repo settings requests from YAML data file
# Filter by organization so only repos belonging to the current provider org are processed
locals {
  settings_yaml_data    = yamldecode(file("${path.module}/../../data/repo-settings-requests.yaml"))
  all_settings_requests = try(local.settings_yaml_data.repo_settings_requests, {})
  repo_settings_requests = {
    for name, req in local.all_settings_requests : name => req
    if try(req.organization, "") == var.organization
  }
}

# GitHub Repository Settings Module — applies branch protection & rulesets to existing repos
module "github_repo_settings" {
  source = "../../modules/github-repo-settings"

  repo_settings_requests = local.repo_settings_requests
}
