---
applyTo: "**"
---

Provide project context and coding guidelines that AI should follow when generating code, answering questions, or reviewing changes.

## Project Overview

**Paloitmbb GitHub Infrastructure as Code (mbb-iac)** is a comprehensive Terraform-based solution for managing GitHub organization infrastructure, including:

- 🏢 GitHub Organization settings and policies
- 📦 Repository creation and configuration management
- 🔒 GitHub Advanced Security (GHAS) integration
- 🤖 GitHub Copilot seat and policy management
- 🔄 Multi-environment support (dev, staging, production)
- 📝 YAML-based repository definitions for scalability

## Project Structure

The project follows this directory structure:

```
mbb-iac/
├── main.tf                    # Root module orchestration
├── variables.tf               # Input variable definitions
├── outputs.tf                 # Output value definitions
├── versions.tf                # Provider and version requirements
├── terraform.tfvars.example   # Example variable values
├── HTTP_BACKEND_SETUP.md      # Backend configuration guide
├── README.md                  # Main project documentation
│
├── .github/                   # GitHub specific files
│   └── instructions/          # AI coding guidelines
│       ├── git.instructions.md        # Commit message conventions
│       ├── structure.instructions.md  # This file
│       └── tech.instructions.md       # Technical guidelines
│
├── modules/                   # Reusable Terraform modules
│   ├── github-organization/   # Organization settings management
│   │   ├── main.tf           # Organization resource definitions
│   │   ├── variables.tf      # Module inputs
│   │   ├── outputs.tf        # Module outputs
│   │   ├── versions.tf       # Module version requirements
│   │   └── README.md         # Module documentation
│   │
│   ├── github-repository/     # Repository management
│   │   ├── main.tf           # Repository, branches, teams
│   │   ├── variables.tf      # Module inputs
│   │   ├── outputs.tf        # Module outputs
│   │   ├── versions.tf       # Module version requirements
│   │   └── README.md         # Module documentation
│   │
│   ├── github-security/       # GHAS configuration
│   │   ├── main.tf           # Security settings and scanning
│   │   ├── variables.tf      # Module inputs
│   │   ├── outputs.tf        # Module outputs
│   │   ├── versions.tf       # Module version requirements
│   │   └── README.md         # Module documentation
│   │
│   └── github-copilot/        # Copilot settings
│       ├── main.tf           # Copilot configuration
│       ├── variables.tf      # Module inputs
│       ├── outputs.tf        # Module outputs
│       ├── versions.tf       # Module version requirements
│       └── README.md         # Module documentation
│
├── environments/              # Environment-specific configurations
│   ├── dev/
│   │   ├── terraform.tfvars  # Development variable values
│   │   ├── backend.tfvars    # Development backend config
│   │   └── README.md         # Environment-specific docs
│   │
│   ├── staging/
│   │   ├── terraform.tfvars  # Staging variable values
│   │   ├── backend.tfvars    # Staging backend config
│   │   └── README.md         # Environment-specific docs
│   │
│   └── production/
│       ├── terraform.tfvars  # Production variable values
│       ├── backend.tfvars    # Production backend config
│       └── README.md         # Environment-specific docs
│
├── data/                      # External data sources (alternative to tfvars)
│   ├── repositories.yaml     # YAML repository definitions
│   ├── README.md             # Data directory documentation
│   ├── EXAMPLES.md           # Configuration examples
│   └── QUICK_START.md        # Quick start guide
│
├── scripts/                   # Helper automation scripts
│   ├── init.sh               # Terraform initialization with backend
│   ├── plan.sh               # Run terraform plan for environment
│   ├── apply.sh              # Run terraform apply for environment
│   ├── validate.sh           # Validate terraform configuration
│   └── import-repos.sh       # Import existing repositories
│
└── docs/                      # Additional documentation
    └── plans/
        └── 01-PROJECT_CREATION_PLAN.md

```

## Key Technologies

- **Terraform**: >= 1.5.7
- **GitHub Provider**: ~> 6.0
- **Backend**: HTTP backend using GitHub Releases for state storage and GitHub API for locking
- **Language**: HCL (HashiCorp Configuration Language)
- **Data Formats**: YAML for repository definitions, TFVARS for configuration

## Module Responsibilities

### github-organization

- Manages organization-level settings (billing email, company info, description)
- Controls default repository permissions
- Sets member creation permissions

### github-repository

- Creates and configures repositories with customizable settings
- Implements branch protection rules
- Manages team access and permissions
- Configures repository features (issues, projects, wiki)
- Sets up topics and default branches

### github-security

- Enables GitHub Advanced Security (GHAS)
- Configures secret scanning and push protection
- Manages Dependabot alerts and security updates
- Controls vulnerability alerts
- Sets security policies per repository

### github-copilot

- Manages Copilot organization settings
- Controls seat assignments for teams and users
- Configures content exclusions
- Sets policy mode and feature flags (IDE chat, CLI)
- Manages public code suggestion settings

## Configuration Patterns

### Repository Management Approaches

**1. YAML-Based (Recommended for many repositories)**

- Define repositories in `data/repositories.yaml`
- Keep `repositories = []` in environment tfvars
- Automatically loaded by root module
- Better for version control and readability at scale

**2. Tfvars-Based (Traditional)**

- Define repositories directly in `environments/{env}/terraform.tfvars`
- Takes precedence over YAML if both exist
- Better for small numbers of repositories

**3. Hybrid Approach**

- Maintain both YAML and tfvars
- Switch by setting/clearing repositories variable in tfvars

## Workflow Scripts

All scripts are located in `scripts/` and should be executed from the project root:

- **init.sh**: Initializes Terraform with environment-specific backend

  ```bash
  ./scripts/init.sh [dev|staging|production]
  ```

- **plan.sh**: Generates execution plan for review

  ```bash
  ./scripts/plan.sh [dev|staging|production]
  ```

- **apply.sh**: Applies infrastructure changes

  ```bash
  ./scripts/apply.sh [dev|staging|production]
  ```

- **validate.sh**: Validates Terraform configuration

  ```bash
  ./scripts/validate.sh
  ```

- **import-repos.sh**: Imports existing GitHub repositories into Terraform state
  ```bash
  ./scripts/import-repos.sh
  ```

## Authentication

The project uses GitHub Personal Access Token or GitHub App authentication:

```bash
export GITHUB_TOKEN="your-github-token"
```

Required token permissions:

- `repo` - Full control of repositories
- `admin:org` - Full control of organizations
- `workflow` - Update GitHub Actions workflows

For HTTP backend, `TF_HTTP_PASSWORD` is automatically set from `GITHUB_TOKEN` by init script.

## State Management

- **Backend Type**: HTTP backend
- **State Storage**: GitHub Releases (tagged state files)
- **State Locking**: GitHub API (git refs)
- **Configuration**: Per-environment in `backend.tfvars`

Example backend configuration:

```hcl
address        = "https://github.com/org/repo/releases/download/state-dev/terraform.tfstate"
lock_address   = "https://api.github.com/repos/org/repo/git/refs/locks/dev"
unlock_address = "https://api.github.com/repos/org/repo/git/refs/locks/dev"
username       = "terraform"
```

## Variable Hierarchy

1. **Root Variables** (`variables.tf`): Define all possible inputs
2. **Environment Tfvars** (`environments/{env}/terraform.tfvars`): Environment-specific values
3. **YAML Data** (`data/repositories.yaml`): Alternative repository definitions
4. **Local Merging** (`main.tf`): Logic to merge YAML and tfvars data

## Output Structure

The project outputs:

- `organization_name`: GitHub organization name
- `repository_source`: Whether repos come from "yaml" or "tfvars"
- `repository_count`: Total number of managed repositories
- `repositories`: Map of repository details (full_name, html_url, ssh_url)
- `copilot_seats`: Copilot seat assignments (sensitive)

## Development Guidelines

When working with this codebase:

1. **Always use scripts** for Terraform operations (init, plan, apply)
2. **Test in dev** environment before staging/production
3. **Follow conventional commits** (see git.instructions.md)
4. **Validate** configuration before committing
5. **Document** module changes in respective README files
6. **Use YAML** for managing multiple repositories
7. **Keep secrets** in environment variables, not in code
8. **Review plans** carefully before applying changes

## Common Operations

### Adding a New Repository

**Option A - YAML:**

```yaml
# data/repositories.yaml
repositories:
  - name: new-repo
    description: "Description"
    visibility: private
    features:
      has_issues: true
      has_projects: false
      has_wiki: false
    default_branch: main
    topics: ["terraform", "github"]
```

**Option B - Tfvars:**

```hcl
# environments/dev/terraform.tfvars
repositories = [
  {
    name        = "new-repo"
    description = "Description"
    visibility  = "private"
    # ... additional configuration
  }
]
```

### Modifying Organization Settings

Edit `environments/{env}/terraform.tfvars`:

```hcl
organization = {
  name                            = "org-name"
  billing_email                   = "email@example.com"
  company                         = "Company Name"
  description                     = "Organization Description"
  default_repository_permission   = "read"
  members_can_create_repositories = false
}
```

### Enabling Copilot

Edit `environments/{env}/terraform.tfvars`:

```hcl
copilot_config = {
  enabled                 = true
  public_code_suggestions = "disabled"
  ide_chat_enabled        = true
  cli_enabled             = true
  policy_mode             = "enabled"
  seat_assignments = {
    teams = ["engineering", "platform"]
    users = ["user@example.com"]
  }
  content_exclusions = ["*.env", "secrets/*"]
}
```
