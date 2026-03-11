# Terraform GitHub Project Scaffolding Plan

## Project Overview

A modular Terraform infrastructure project to manage GitHub organization, repositories, GitHub Advanced Security (GHAS), and GitHub Copilot configurations.

## Project Structure

```
mbb-iac/
├── README.md
├── .gitignore
├── .terraform-docs.yml
├── versions.tf                      # Terraform and provider versions
├── main.tf                          # Root module orchestration
├── variables.tf                     # Root module variables
├── outputs.tf                       # Root module outputs
├── terraform.tfvars.example         # Example tfvars file
├── environments/
│   ├── dev/
│   │   ├── terraform.tfvars
│   │   ├── backend.tfvars
│   │   └── README.md
│   └── production/
│       ├── terraform.tfvars
│       ├── backend.tfvars
│       └── README.md
├── modules/
│   ├── github-organization/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── versions.tf
│   │   └── README.md
│   ├── github-repository/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── versions.tf
│   │   └── README.md
│   ├── github-security/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── versions.tf
│   │   └── README.md
│   └── github-copilot/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf
│       └── README.md
├── data/
│   └── repositories.yaml            # Optional: external data source
└── scripts/
    ├── init.sh
    ├── plan.sh
    ├── apply.sh
    └── validate.sh
```

## Module Breakdown

### 1. github-organization Module

Manages organization-level settings and configurations.

**Resources:**

- Organization settings
- Organization secrets
- Organization variables
- Organization webhooks
- Organization security managers
- Default repository settings

**Key Variables:**

- `organization_name` - Name of the GitHub organization
- `billing_email` - Billing contact email
- `company` - Company name
- `description` - Organization description
- `default_repository_permission` - Default permission level for organization members
- `members_can_create_repositories` - Whether members can create repositories

**Example Usage:**

```hcl
module "github_organization" {
  source = "./modules/github-organization"

  organization_name                  = var.organization.name
  billing_email                      = var.organization.billing_email
  company                            = var.organization.company
  description                        = var.organization.description
  default_repository_permission      = var.organization.default_repository_permission
  members_can_create_repositories    = var.organization.members_can_create_repositories
}
```

### 2. github-repository Module

Creates and manages repository configurations.

**Resources:**

- Repository creation
- Branch protection rules
- Repository collaborators/teams
- Repository webhooks
- Deploy keys
- Repository topics and settings

**Key Variables:**

- `repository_name` - Name of the repository
- `description` - Repository description
- `visibility` - Repository visibility (public/private/internal)
- `has_issues` - Enable issues
- `has_projects` - Enable projects
- `has_wiki` - Enable wiki
- `default_branch` - Default branch name
- `branch_protection_rules` - Branch protection configurations
- `collaborators` - Repository collaborators
- `teams` - Team access permissions
- `repository_secrets` - Repository-level secrets
- `repository_variables` - Repository-level variables
- `topics` - Repository topics/tags
- `auto_init` - Initialize repository with README
- `gitignore_template` - Gitignore template to use
- `license_template` - License template to use

**Example Usage:**

```hcl
module "github_repository" {
  source   = "./modules/github-repository"
  for_each = { for repo in var.repositories : repo.name => repo }

  repository_name           = each.value.name
  description               = each.value.description
  visibility                = each.value.visibility
  has_issues                = each.value.features.has_issues
  has_projects              = each.value.features.has_projects
  has_wiki                  = each.value.features.has_wiki
  default_branch            = each.value.default_branch
  branch_protection_rules   = each.value.branch_protection
  teams                     = each.value.teams
  repository_secrets        = each.value.secrets
  repository_variables      = each.value.variables
}
```

### 3. github-security Module

Manages GHAS (GitHub Advanced Security) settings.

**Resources:**

- Security and analysis features
- Code scanning configurations
- Dependabot configuration
- Secret scanning settings
- Security advisories
- Vulnerability alerts

**Key Variables:**

- `repository_name` - Repository to configure security for
- `enable_vulnerability_alerts` - Enable vulnerability alerts
- `enable_security_fixes` - Enable automated security fixes
- `enable_advanced_security` - Enable GitHub Advanced Security
- `enable_secret_scanning` - Enable secret scanning
- `enable_secret_scanning_push_protection` - Enable push protection for secrets
- `enable_dependabot_alerts` - Enable Dependabot alerts
- `enable_dependabot_security_updates` - Enable Dependabot security updates
- `code_scanning_default_setup` - Code scanning default configuration
- `dependabot_config` - Dependabot configuration settings

**Example Usage:**

```hcl
module "github_security" {
  source   = "./modules/github-security"
  for_each = { for repo in var.repositories : repo.name => repo if repo.security != null }

  repository_name                        = each.value.name
  enable_vulnerability_alerts            = each.value.security.enable_vulnerability_alerts
  enable_advanced_security               = each.value.security.enable_advanced_security
  enable_secret_scanning                 = each.value.security.enable_secret_scanning
  enable_secret_scanning_push_protection = each.value.security.enable_secret_scanning_push_protection
  enable_dependabot_alerts               = each.value.security.enable_dependabot_alerts
  enable_dependabot_security_updates     = each.value.security.enable_dependabot_security_updates
}
```

### 4. github-copilot Module

Manages GitHub Copilot organization settings.

**Resources:**

- Copilot organization settings
- Copilot seat assignments
- Copilot policies
- Copilot content exclusions

**Key Variables:**

- `organization_name` - Name of the GitHub organization
- `copilot_enabled` - Enable Copilot for organization
- `seat_assignments` - User and team seat assignments
- `public_code_suggestions` - Policy for public code suggestions (enabled/disabled/unconfigured)
- `ide_chat_enabled` - Enable IDE chat features
- `cli_enabled` - Enable Copilot CLI
- `content_exclusions` - Paths to exclude from Copilot
- `policy_mode` - Copilot policy mode (enabled/disabled/unconfigured)

**Example Usage:**

```hcl
module "github_copilot" {
  source = "./modules/github-copilot"

  organization_name       = var.organization.name
  copilot_enabled         = var.copilot_config.enabled
  public_code_suggestions = var.copilot_config.public_code_suggestions
  ide_chat_enabled        = var.copilot_config.ide_chat_enabled
  cli_enabled             = var.copilot_config.cli_enabled
  policy_mode             = var.copilot_config.policy_mode
  seat_assignments        = var.copilot_config.seat_assignments
  content_exclusions      = var.copilot_config.content_exclusions
}
```

## Tfvars File Structure

### Root Level: `environments/{env}/terraform.tfvars`

```hcl
# Organization Configuration
organization = {
  name                            = "paloitmbb"
  billing_email                   = "billing@paloitmbb.com"
  company                         = "Paloitmbb"
  description                     = "Paloitmbb GitHub Organization"
  default_repository_permission   = "read"
  members_can_create_repositories = false
}

# Repositories Configuration
# Note: Using YAML data file approach - leave empty to load from data/repositories.yaml
# Or define repositories here to override the YAML file
repositories = []

# GHAS Configuration
ghas_config = {
  default_enabled = true

  organization_level = {
    enable_secret_scanning     = true
    enable_push_protection     = true
    enable_dependabot_alerts   = true
    enable_dependency_graph    = true
  }
}

# Copilot Configuration
copilot_config = {
  enabled                 = true
  public_code_suggestions = "disabled"
  ide_chat_enabled        = true
  cli_enabled             = true
  policy_mode             = "enabled"

  seat_assignments = {
    teams = ["engineering", "platform"]
    users = ["admin@paloitmbb.com", "tech-lead@paloitmbb.com"]
  }

  content_exclusions = [
    "*.env",
    "*.key",
    "*.pem",
    "secrets/*",
    "credentials/*",
    ".ssh/*"
  ]
}

# Teams Configuration
teams = [
  {
    name        = "engineering"
    description = "Engineering Team"
    privacy     = "closed"
    members     = ["user1", "user2", "user3"]
    maintainers = ["tech-lead"]
  },
  {
    name        = "platform"
    description = "Platform Team"
    privacy     = "closed"
    members     = ["platform1", "platform2"]
    maintainers = ["platform-lead"]
  }
]
```

### Backend Configuration: `environments/{env}/backend.tfvars`

```hcl
# Azure Storage Backend
resource_group_name  = "mbb"
storage_account_name = "mbbtfstate"
container_name       = "tfstate"
key                  = "github.terraform.tfstate"
```

## Implementation Steps

### Phase 1: Foundation Setup

1. **Initialize Project Structure**

   ```bash
   mkdir -p modules/{github-organization,github-repository,github-security,github-copilot}
   mkdir -p environments/{dev,production}
   mkdir -p data scripts
   ```

2. **Set Up Version Control**
   - Initialize git repository
   - Create `.gitignore` file
   - Set up branch protection rules

3. **Configure Backend**
   - Set up Azure Blob Storage backend
   - Create Azure resource group and storage account
   - Configure state locking via Azure Blob Lease
   - Test backend connectivity with Azure credentials

4. **Authentication Setup**
   - Generate GitHub Personal Access Token or App credentials
   - Set up environment variables
   - Document authentication process

### Phase 2: Module Development

#### Step 1: github-organization Module

- Create module structure
- Define organization settings resources
- Implement organization secrets management
- Add organization variables support
- Document module variables and outputs

#### Step 2: github-repository Module

- Create repository resource
- Add branch protection rules
- Implement team access management
- Add webhook configuration
- Support repository secrets/variables
- Document usage examples

#### Step 3: github-security Module

- Implement GHAS feature toggles
- Configure Dependabot settings
- Set up secret scanning
- Add code scanning configuration
- Document security best practices

#### Step 4: github-copilot Module

- Configure Copilot organization settings
- Implement seat assignment logic
- Add content exclusion rules
- Set up policy management
- Document Copilot features

### Phase 3: Integration

1. **Root Module Configuration**
   - Create `main.tf` orchestrating all modules
   - Define variable types with validation
   - Set up module dependencies
   - Configure outputs

2. **Environment Configuration**
   - Create dev environment tfvars
   - Create production environment tfvars
   - Document environment differences

3. **Testing**
   - Validate Terraform configurations
   - Test in dev environment
   - Run plan for all environments
   - Document test results

### Phase 4: Automation & Documentation

1. **Create Helper Scripts**

   ```bash
   # scripts/init.sh
   # scripts/plan.sh
   # scripts/apply.sh
   # scripts/validate.sh
   ```

2. **Documentation**
   - Main README with overview
   - Module-specific READMEs
   - Variable documentation
   - Architecture diagrams
   - Runbook for operations

3. **CI/CD Setup**
   - GitHub Actions workflow for validation
   - Automated terraform plan on PRs
   - Automated terraform apply on merge
   - State file backup strategy

4. **Pre-commit Hooks**
   - Terraform fmt
   - Terraform validate
   - tflint
   - terraform-docs

## Provider Configuration

### versions.tf

```hcl
terraform {
  required_version = ">= 1.14.5"

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
```

### main.tf (Root Module)

```hcl
# Load repositories from YAML data file
locals {
  repositories_file = "${path.module}/data/repositories.yaml"
  repositories_data = fileexists(local.repositories_file) ? yamldecode(file(local.repositories_file)) : { repositories = [] }

  # Merge repositories from YAML file and tfvars (tfvars takes precedence if both exist)
  yaml_repositories = local.repositories_data.repositories
  all_repositories  = length(var.repositories) > 0 ? var.repositories : local.yaml_repositories
}

# Organization Management
module "github_organization" {
  source = "./modules/github-organization"

  organization_name               = var.organization.name
  billing_email                   = var.organization.billing_email
  company                         = var.organization.company
  description                     = var.organization.description
  default_repository_permission   = var.organization.default_repository_permission
  members_can_create_repositories = var.organization.members_can_create_repositories
}

# Repository Management
module "github_repositories" {
  source   = "./modules/github-repository"
  for_each = { for repo in local.all_repositories : repo.name => repo }

  repository_name         = each.value.name
  description             = each.value.description
  visibility              = each.value.visibility
  has_issues              = each.value.features.has_issues
  has_projects            = each.value.features.has_projects
  has_wiki                = each.value.features.has_wiki
  default_branch          = each.value.default_branch
  topics                  = each.value.topics
  branch_protection_rules = each.value.branch_protection
  teams                   = each.value.teams
  repository_secrets      = each.value.secrets
  repository_variables    = each.value.variables

  depends_on = [module.github_organization]
}

# Security Configuration
module "github_security" {
  source   = "./modules/github-security"
  for_each = { for repo in local.all_repositories : repo.name => repo if repo.security != null }

  repository_name                        = each.value.name
  enable_vulnerability_alerts            = each.value.security.enable_vulnerability_alerts
  enable_advanced_security               = each.value.security.enable_advanced_security
  enable_secret_scanning                 = each.value.security.enable_secret_scanning
  enable_secret_scanning_push_protection = each.value.security.enable_secret_scanning_push_protection
  enable_dependabot_alerts               = each.value.security.enable_dependabot_alerts
  enable_dependabot_security_updates     = each.value.security.enable_dependabot_security_updates

  depends_on = [module.github_repositories]
}

# Copilot Configuration
module "github_copilot" {
  source = "./modules/github-copilot"

  organization_name       = var.organization.name
  copilot_enabled         = var.copilot_config.enabled
  public_code_suggestions = var.copilot_config.public_code_suggestions
  ide_chat_enabled        = var.copilot_config.ide_chat_enabled
  cli_enabled             = var.copilot_config.cli_enabled
  policy_mode             = var.copilot_config.policy_mode
  seat_assignments        = var.copilot_config.seat_assignments
  content_exclusions      = var.copilot_config.content_exclusions

  depends_on = [module.github_organization]
}
```

## Key Features

### Modularity

- **Separation of Concerns**: Each module handles specific GitHub functionality
- **Reusability**: Modules can be used independently or together
- **Composability**: Easy to add/remove features per repository
- **Maintainability**: Changes isolated to specific modules

### Configuration Management

- **Environment Segregation**: Separate tfvars per environment
- **DRY Principle**: Shared defaults with environment-specific overrides
- **Type Safety**: Strong variable typing with validation rules
- **Version Control**: All configurations tracked in git

### Security Best Practices

- **No Hardcoded Secrets**: Use environment variables or secret stores
- **State Encryption**: Remote backend with encryption at rest
- **Least Privilege**: Granular permission management
- **Audit Trail**: All changes tracked in version control
- **Compliance**: GHAS integration for security scanning

### Operational Excellence

- **Automation**: Scripts for common operations
- **Validation**: Pre-commit hooks and CI/CD checks
- **Documentation**: Comprehensive module and variable docs
- **Monitoring**: Terraform state tracking and drift detection

## Security Considerations

### Authentication

- Use GitHub App for better security and rate limits
- Store credentials in secure secret management system
- Rotate tokens regularly
- Use least privilege access

### State Management

- State stored in Azure Blob Storage (encrypted in transit via HTTPS)
- State locking via Azure Blob Lease
- Automatic state versioning through Azure Blob versioning
- Access controls via Azure RBAC
- State backup through Azure Blob soft delete

### Secrets Management

- Never commit secrets to version control
- Use external secret management (AWS Secrets Manager, Vault, etc.)
- Reference secrets by name/ID only
- Enable audit logging for secret access

## Maintenance & Operations

### Regular Tasks

- Review and update provider versions
- Audit security configurations
- Review Copilot seat assignments
- Update branch protection rules as needed
- Review Dependabot alerts

### Disaster Recovery

- State file backup strategy
- Documentation of manual steps
- Rollback procedures
- Emergency contact information

### Monitoring

- Terraform drift detection
- Security alert monitoring
- Copilot usage analytics
- Repository compliance checks

## Future Enhancements

### Potential Additions

- GitHub Actions workflow management
- Issue and PR template management
- GitHub Pages configuration
- GitHub Discussions setup
- Repository rulesets
- Custom properties management
- Deployment protection rules
- Environment secrets and variables

### Advanced Features

- Dynamic repository creation from YAML
- Automated security policy enforcement
- Cost tracking and optimization
- Compliance reporting
- Integration with external systems

## GitOps Workflow: Dynamic Repository Creation

### Overview

This section describes a fully automated GitOps workflow for creating repositories through GitHub Issues and Actions. The workflow enables self-service repository creation while maintaining governance and approval processes.

**Repository Configuration Approach:**

This workflow uses the **YAML data file approach** (`data/repositories.yaml`) for managing repository definitions. This provides:

- Simpler, more readable syntax for non-Terraform users
- Centralized repository management in one file
- Easy validation and parsing
- Clean separation between data and infrastructure code

See the [`data/` directory documentation](data/README.md) for more details on the YAML approach.

### Workflow Architecture

**Process Flow:**

1. Developer creates a GitHub Issue using the "New Repository Request" template
2. GitHub Actions automatically parses the issue and generates YAML configuration
3. A Pull Request is created with changes to `data/repositories.yaml`
4. YAML validation and Terraform plan run automatically
5. Team reviews and approves the PR
6. Upon merge, Terraform apply executes automatically
7. Repository is created with all specified configurations
8. Issue is automatically closed with success notification

### Implementation Components

#### 1. Issue Template: `.github/ISSUE_TEMPLATE/new-repository.yml`

```yaml
name: New Repository Request
description: Request creation of a new GitHub repository
title: "[REPO REQUEST] "
labels: ["repo-request", "pending-review"]
body:
  - type: input
    id: repo-name
    attributes:
      label: Repository Name
      description: Name of the new repository (lowercase, hyphens only)
      placeholder: "my-new-service"
    validations:
      required: true

  - type: textarea
    id: description
    attributes:
      label: Description
      description: Brief description of the repository purpose
    validations:
      required: true

  - type: dropdown
    id: visibility
    attributes:
      label: Visibility
      options:
        - private
        - internal
        - public
    validations:
      required: true

  - type: dropdown
    id: environment
    attributes:
      label: Environment
      description: Which environment to create this in
      options:
        - dev
        - production
    validations:
      required: true

  - type: checkboxes
    id: features
    attributes:
      label: Repository Features
      options:
        - label: Enable Issues
        - label: Enable Projects
        - label: Enable Wiki

  - type: checkboxes
    id: security
    attributes:
      label: Security Features (GHAS)
      options:
        - label: Enable Advanced Security
        - label: Enable Secret Scanning
        - label: Enable Secret Scanning Push Protection
        - label: Enable Dependabot Alerts
        - label: Enable Dependabot Security Updates

  - type: input
    id: topics
    attributes:
      label: Topics
      description: Comma-separated list of topics
      placeholder: "frontend, react, typescript"

  - type: dropdown
    id: default-branch
    attributes:
      label: Default Branch
      options:
        - main
        - master
      default: 0

  - type: textarea
    id: teams
    attributes:
      label: Team Access
      description: |
        List teams and their permissions (one per line)
        Format: team-name:permission (push, pull, admin, maintain)
      placeholder: |
        engineering:push
        platform:admin

  - type: textarea
    id: branch-protection
    attributes:
      label: Branch Protection Rules
      description: Customize if needed (optional)
      placeholder: |
        Required reviewers: 2
        Require code owner reviews: yes
        Require status checks: ci/test, ci/lint
```

#### 2. Repository Request Workflow: `.github/workflows/repo-request.yml`

```yaml
name: Process Repository Request

on:
  issues:
    types: [opened, labeled]

permissions:
  issues: write
  contents: write
  pull-requests: write

jobs:
  process-request:
    runs-on: ubuntu-latest
    if: contains(github.event.issue.labels.*.name, 'repo-request')

    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Parse issue form
        id: parse
        uses: stefanbuck/github-issue-parser@v3
        with:
          template-path: .github/ISSUE_TEMPLATE/new-repository.yml

      - name: Extract and validate data
        id: extract
        run: |
          echo "Parsing issue data..."

          # Extract values from parsed JSON
          REPO_NAME=$(echo '${{ steps.parse.outputs.jsonString }}' | jq -r '.["repo-name"]')
          DESCRIPTION=$(echo '${{ steps.parse.outputs.jsonString }}' | jq -r '.description')
          VISIBILITY=$(echo '${{ steps.parse.outputs.jsonString }}' | jq -r '.visibility')
          ENVIRONMENT=$(echo '${{ steps.parse.outputs.jsonString }}' | jq -r '.environment')
          TOPICS=$(echo '${{ steps.parse.outputs.jsonString }}' | jq -r '.topics // ""')
          DEFAULT_BRANCH=$(echo '${{ steps.parse.outputs.jsonString }}' | jq -r '.["default-branch"] // "main"')

          # Parse features
          HAS_ISSUES=$(echo '${{ steps.parse.outputs.jsonString }}' | jq -r '.features | contains(["Enable Issues"])')
          HAS_PROJECTS=$(echo '${{ steps.parse.outputs.jsonString }}' | jq -r '.features | contains(["Enable Projects"])')
          HAS_WIKI=$(echo '${{ steps.parse.outputs.jsonString }}' | jq -r '.features | contains(["Enable Wiki"])')

          # Parse security features
          ENABLE_ADVANCED_SECURITY=$(echo '${{ steps.parse.outputs.jsonString }}' | jq -r '.security | contains(["Enable Advanced Security"])')
          ENABLE_SECRET_SCANNING=$(echo '${{ steps.parse.outputs.jsonString }}' | jq -r '.security | contains(["Enable Secret Scanning"])')
          ENABLE_PUSH_PROTECTION=$(echo '${{ steps.parse.outputs.jsonString }}' | jq -r '.security | contains(["Enable Secret Scanning Push Protection"])')
          ENABLE_DEPENDABOT=$(echo '${{ steps.parse.outputs.jsonString }}' | jq -r '.security | contains(["Enable Dependabot Alerts"])')
          ENABLE_DEPENDABOT_UPDATES=$(echo '${{ steps.parse.outputs.jsonString }}' | jq -r '.security | contains(["Enable Dependabot Security Updates"])')

          # Validate repository name
          if [[ ! "$REPO_NAME" =~ ^[a-z0-9-]+$ ]]; then
            echo "error=Invalid repository name. Use lowercase letters, numbers, and hyphens only." >> $GITHUB_OUTPUT
            exit 1
          fi

          # Set outputs
          echo "repo_name=$REPO_NAME" >> $GITHUB_OUTPUT
          echo "description=$DESCRIPTION" >> $GITHUB_OUTPUT
          echo "visibility=$VISIBILITY" >> $GITHUB_OUTPUT
          echo "environment=$ENVIRONMENT" >> $GITHUB_OUTPUT
          echo "topics=$TOPICS" >> $GITHUB_OUTPUT
          echo "default_branch=$DEFAULT_BRANCH" >> $GITHUB_OUTPUT
          echo "has_issues=$HAS_ISSUES" >> $GITHUB_OUTPUT
          echo "has_projects=$HAS_PROJECTS" >> $GITHUB_OUTPUT
          echo "has_wiki=$HAS_WIKI" >> $GITHUB_OUTPUT
          echo "enable_advanced_security=$ENABLE_ADVANCED_SECURITY" >> $GITHUB_OUTPUT
          echo "enable_secret_scanning=$ENABLE_SECRET_SCANNING" >> $GITHUB_OUTPUT
          echo "enable_push_protection=$ENABLE_PUSH_PROTECTION" >> $GITHUB_OUTPUT
          echo "enable_dependabot=$ENABLE_DEPENDABOT" >> $GITHUB_OUTPUT
          echo "enable_dependabot_updates=$ENABLE_DEPENDABOT_UPDATES" >> $GITHUB_OUTPUT

      - name: Generate YAML configuration
        id: generate
        run: |
          REPO_NAME="${{ steps.extract.outputs.repo_name }}"
          YAML_FILE="data/repositories.yaml"

          # Parse topics into YAML array format
          IFS=',' read -ra TOPICS_ARRAY <<< "${{ steps.extract.outputs.topics }}"
          TOPICS_YAML=""
          for topic in "${TOPICS_ARRAY[@]}"; do
            topic=$(echo "$topic" | xargs) # trim whitespace
            if [ -n "$topic" ]; then
              TOPICS_YAML+="      - $topic\n"
            fi
          done

          # If no topics, use empty array
          if [ -z "$TOPICS_YAML" ]; then
            TOPICS_YAML="      []"
          fi

          # Create backup
          if [ -f "$YAML_FILE" ]; then
            cp "$YAML_FILE" "${YAML_FILE}.backup"
          fi

          # Append new repository configuration to YAML file
          cat >> "$YAML_FILE" << EOF

  # Repository: $REPO_NAME (Created from Issue #${{ github.event.issue.number }})
  - name: ${{ steps.extract.outputs.repo_name }}
    description: ${{ steps.extract.outputs.description }}
    visibility: ${{ steps.extract.outputs.visibility }}
    features:
      has_issues: ${{ steps.extract.outputs.has_issues }}
      has_projects: ${{ steps.extract.outputs.has_projects }}
      has_wiki: ${{ steps.extract.outputs.has_wiki }}
    default_branch: ${{ steps.extract.outputs.default_branch }}
    topics:
$(echo -e "$TOPICS_YAML")
    security:
      enable_vulnerability_alerts: true
      enable_advanced_security: ${{ steps.extract.outputs.enable_advanced_security }}
      enable_secret_scanning: ${{ steps.extract.outputs.enable_secret_scanning }}
      enable_secret_scanning_push_protection: ${{ steps.extract.outputs.enable_push_protection }}
      enable_dependabot_alerts: ${{ steps.extract.outputs.enable_dependabot }}
      enable_dependabot_security_updates: ${{ steps.extract.outputs.enable_dependabot_updates }}
    branch_protection:
      pattern: ${{ steps.extract.outputs.default_branch }}
      required_approving_review_count: 2
      require_code_owner_reviews: true
      dismiss_stale_reviews: true
      require_signed_commits: false
      enforce_admins: false
    teams: []
    secrets: {}
    variables: {}
EOF

          echo "branch_name=repo-request/$REPO_NAME" >> $GITHUB_OUTPUT

      - name: Validate YAML
        run: |
          # Validate YAML syntax
          python3 -c "import yaml; yaml.safe_load(open('data/repositories.yaml'))" && echo "✓ YAML is valid" || exit 1

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.14.5

      - name: Validate Terraform
        run: |
          # Validate that Terraform can parse the YAML
          terraform init -backend=false
          terraform validate

      - name: Create Pull Request
        id: create-pr
        uses: peter-evans/create-pull-request@v6
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          commit-message: |
            feat: Add repository ${{ steps.extract.outputs.repo_name }}

            Requested in issue #${{ github.event.issue.number }}
          branch: ${{ steps.generate.outputs.branch_name }}
          delete-branch: true
          title: "[REPO] Create repository: ${{ steps.extract.outputs.repo_name }}"
          body: |
            ## Repository Creation Request

            This PR was automatically generated from issue #${{ github.event.issue.number }}

            ### Repository Details
            - **Name**: `${{ steps.extract.outputs.repo_name }}`
            - **Description**: ${{ steps.extract.outputs.description }}
            - **Visibility**: ${{ steps.extract.outputs.visibility }}
            - **File**: `data/repositories.yaml`

            ### Features
            - Issues: ${{ steps.extract.outputs.has_issues }}
            - Projects: ${{ steps.extract.outputs.has_projects }}
            - Wiki: ${{ steps.extract.outputs.has_wiki }}

            ### Security (GHAS)
            - Advanced Security: ${{ steps.extract.outputs.enable_advanced_security }}
            - Secret Scanning: ${{ steps.extract.outputs.enable_secret_scanning }}
            - Push Protection: ${{ steps.extract.outputs.enable_push_protection }}
            - Dependabot Alerts: ${{ steps.extract.outputs.enable_dependabot }}
            - Dependabot Updates: ${{ steps.extract.outputs.enable_dependabot_updates }}

            ### Review Checklist
            - [ ] Repository name follows naming conventions
            - [ ] Security settings are appropriate for the repository type
            - [ ] Team access is correctly configured
            - [ ] Branch protection rules are adequate
            - [ ] YAML syntax is valid

            ### Next Steps
            1. Review the YAML configuration changes in `data/repositories.yaml`
            2. Approve and merge this PR
            3. The repository will be created automatically

            ---
            Closes #${{ github.event.issue.number }}
          labels: |
            repo-creation
            terraform
            automated

      - name: Comment on issue
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `✅ Pull request created: ${{ steps.create-pr.outputs.pull-request-url }}

              The repository configuration has been added to \`data/repositories.yaml\`. Once the PR is reviewed and merged, the repository will be created automatically.`
            })

      - name: Add label to issue
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.addLabels({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              labels: ['pr-created']
            })
```

#### 3. Terraform Plan Workflow: `.github/workflows/terraform-plan.yml`

```yaml
name: Terraform Plan

on:
  pull_request:
    paths:
      - "environments/**/*.tfvars"
      - "data/**/*.yaml"
      - "data/**/*.yml"
      - "modules/**/*.tf"
      - "*.tf"

permissions:
  contents: read
  pull-requests: write

jobs:
  terraform-plan:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [dev, production]

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.14.5

      - name: Terraform Init
        run: |
          cd environments/${{ matrix.environment }}
          terraform init -backend-config=backend.tfvars
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_PAT }}

      - name: Terraform Validate
        run: |
          cd environments/${{ matrix.environment }}
          terraform validate

      - name: Terraform Format Check
        run: terraform fmt -check -recursive

      - name: Validate YAML Data Files
        if: hashFiles('data/*.yaml') != '' || hashFiles('data/*.yml') != ''
        run: |
          echo "Validating YAML files..."
          for file in data/*.yaml data/*.yml; do
            if [ -f "$file" ]; then
              echo "Checking $file"
              python3 -c "import yaml; yaml.safe_load(open('$file'))" && echo "✓ $file is valid" || exit 1
            fi
          done

  terraform-plan:
    needs: detect-environments
    if: needs.detect-environments.outputs.environments != '[]'
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: ${{ fromJson(needs.detect-environments.outputs.environments) }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.14.5

      - name: Terraform Init
        run: |
          cd environments/${{ matrix.environment }}
          terraform init -backend-config=backend.tfvars
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_PAT }}

      - name: Terraform Validate
        run: |
          cd environments/${{ matrix.environment }}
          terraform validate

      - name: Terraform Format Check
        run: |
          terraform fmt -check -recursive

      - name: Terraform Plan
        id: plan
        run: |
          cd environments/${{ matrix.environment }}
          terraform plan -var-file=terraform.tfvars -no-color
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_PAT }}
        continue-on-error: true

      - name: Comment Plan on PR
        uses: actions/github-script@v7
        with:
          script: |
            const output = `#### Terraform Plan for \`${{ matrix.environment }}\` 📖

            <details><summary>Show Plan</summary>

            \`\`\`terraform
            ${{ steps.plan.outputs.stdout }}
            \`\`\`

            </details>

            *Pushed by: @${{ github.actor }}, Action: \`${{ github.event_name }}\`*`;

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: output
            })

      - name: Terraform Plan Status
        if: steps.plan.outcome == 'failure'
        run: exit 1
```

#### 4. Terraform Apply Workflow: `.github/workflows/terraform-apply.yml`

```yaml
name: Terraform Apply

on:
  push:
    branches:
      - main
    paths:
      - "environments/**/*.tfvars"
      - "data/**/*.yaml"
      - "data/**/*.yml"
      - "modules/**/*.tf"
      - "*.tf"
  workflow_dispatch:
    inputs:
      environment:
        description: "Environment to apply"
        required: true
        type: choice
        options:
          - dev
          - production

permissions:
  contents: read
  issues: write
  pull-requests: write

jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      environments: ${{ steps.detect.outputs.environments }}
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 2

      - name: Detect changed environments
        id: detect
        run: |
          if [ "${{ github.event_name }}" == "workflow_dispatch" ]; then
            echo "environments=[\"${{ inputs.environment }}\"]" >> $GITHUB_OUTPUT
          else
            # Detect which environment folders changed
            CHANGED_FILES=$(git diff --name-only HEAD^ HEAD)
            ENVIRONMENTS=()

            for env in dev production; do
              if echo "$CHANGED_FILES" | grep -q "environments/${env}/"; then
                ENVIRONMENTS+=("\"$env\"")
              fi
            done

            if [ ${#ENVIRONMENTS[@]} -eq 0 ]; then
              echo "environments=[]" >> $GITHUB_OUTPUT
            else
              ENV_JSON=$(IFS=,; echo "[${ENVIRONMENTS[*]}]")
              echo "environments=$ENV_JSON" >> $GITHUB_OUTPUT
            fi
          fi

  terraform-apply:
    needs: detect-changes
    if: needs.detect-changes.outputs.environments != '[]'
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: ${{ fromJson(needs.detect-changes.outputs.environments) }}

    environment:
      name: ${{ matrix.environment }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.14.5

      - name: Terraform Init
        run: |
          cd environments/${{ matrix.environment }}
          terraform init -backend-config=backend.tfvars
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_PAT }}

      - name: Terraform Plan
        id: plan
        run: |
          cd environments/${{ matrix.environment }}
          terraform plan -var-file=terraform.tfvars -out=tfplan
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_PAT }}

      - name: Terraform Apply
        id: apply
        run: |
          cd environments/${{ matrix.environment }}
          terraform apply -auto-approve tfplan
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_PAT }}

      - name: Get created repositories
        id: get-repos
        run: |
          cd environments/${{ matrix.environment }}
          terraform output -json repositories > repos.json
          echo "repos_json<<EOF" >> $GITHUB_OUTPUT
          cat repos.json >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT

      - name: Comment on linked issues
        uses: actions/github-script@v7
        with:
          script: |
            // Find PR that was merged
            const { data: prs } = await github.rest.pulls.list({
              owner: context.repo.owner,
              repo: context.repo.repo,
              state: 'closed',
              sort: 'updated',
              direction: 'desc',
              per_page: 10
            });

            const mergedPR = prs.find(pr =>
              pr.merged_at &&
              pr.head.ref.startsWith('repo-request/') &&
              pr.merge_commit_sha === context.sha
            );

            if (!mergedPR) {
              console.log('No merged PR found');
              return;
            }

            // Extract issue number from PR body
            const issueMatch = mergedPR.body.match(/#(\d+)/);
            if (!issueMatch) {
              console.log('No issue reference found');
              return;
            }

            const issueNumber = parseInt(issueMatch[1]);

            // Comment on the issue
            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: issueNumber,
              body: `✅ Repository has been created successfully!

              **Environment**: ${{ matrix.environment }}
              **Terraform Apply**: Completed

              The repository is now available and configured with all requested settings.`
            });

            // Close the issue
            await github.rest.issues.update({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: issueNumber,
              state: 'closed',
              state_reason: 'completed'
            });

            // Add success label
            await github.rest.issues.addLabels({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: issueNumber,
              labels: ['completed']
            });
```

### Workflow Features

#### Self-Service Capabilities

- Developers can request repositories without direct access to Terraform
- Standardized form ensures consistent repository configuration
- Automatic validation of input data

#### Governance & Compliance

- All changes go through Pull Request review process
- Terraform plan visible before execution
- Audit trail in both issues and git history
- Approval gates through GitHub environments

#### Automation Benefits

- Reduces manual work and human error
- Consistent repository configuration
- Immediate feedback on configuration validity
- Automatic issue closure and notification
- **YAML-based approach**: Simpler syntax for non-Terraform users
- **Centralized management**: All repositories in one `data/repositories.yaml` file
- **YAML validation**: Automatic syntax checking before Terraform runs

### Required Secrets

Configure these secrets in your GitHub repository settings:

```bash
# GitHub Personal Access Token or App credentials
GITHUB_PAT         # Token with repo, workflow, admin:org permissions

# Azure credentials for backend state storage
ARM_CLIENT_ID      # Azure Service Principal Application ID
ARM_SUBSCRIPTION_ID # Azure Subscription ID
ARM_TENANT_ID      # Azure AD Tenant ID
```

### Environment Protection Rules

Configure environment protection rules in GitHub:

1. **Development**: No protection, auto-deploy
2. **Production**: Require 2 reviewers, delay timer

### Usage Example

**Step 1**: Developer creates issue using template

- Fills in repository name: `customer-api`
- Description: "REST API for customer management"
- Selects environment: `production`
- Enables GHAS features

**Step 2**: Automation kicks in

- GitHub Actions parses issue
- Generates Terraform configuration
- Creates PR with changes
- Runs terraform plan

**Step 3**: Review process

- Team reviews PR and plan output
- Approves changes
- Merges to main

**Step 4**: Automatic execution

- Terraform apply runs
- Repository is created
- Issue is closed with confirmation

### Monitoring & Troubleshooting

#### Workflow Logs

All GitHub Actions workflows provide detailed logs accessible via:

- Actions tab in GitHub UI
- Direct links in PR comments
- Issue notifications

#### Common Issues

**Issue: Terraform validation fails**

- Check tfvars syntax
- Verify repository name format
- Review security feature compatibility

**Issue: PR creation fails**

- Verify GITHUB_TOKEN permissions
- Check branch protection rules
- Ensure no duplicate repository names

**Issue: Terraform apply fails**

- Review plan output for errors
- Check GitHub PAT permissions
- Verify backend configuration

### Best Practices

1. **Naming Conventions**: Enforce strict repository naming in validation
2. **Default Settings**: Use sensible defaults in issue template
3. **Review Process**: Always require approval for production
4. **Documentation**: Keep issue templates updated with examples
5. **Monitoring**: Set up notifications for workflow failures

### Security Considerations

- **Token Security**: Use GitHub Apps instead of PATs when possible
- **Least Privilege**: Scope workflow permissions minimally
- **Environment Secrets**: Use environment-specific secrets
- **Audit Logs**: Enable GitHub audit log streaming
- **State Protection**: Ensure Terraform state is encrypted and access-controlled

## Getting Started

### Prerequisites

- Terraform >= 1.14.5
- GitHub organization with admin access
- GitHub Personal Access Token or App credentials
- Backend storage configured (S3, Terraform Cloud, etc.)

### Initial Setup

```bash
# 1. Clone the repository
git clone <repository-url>
cd mbb-iac

# 2. Set up authentication
export GITHUB_TOKEN="your-github-token"

# 3. Initialize Terraform for dev environment
cd environments/dev
terraform init -backend-config=backend.tfvars

# 4. Review the plan
terraform plan -var-file=terraform.tfvars

# 5. Apply the configuration
terraform apply -var-file=terraform.tfvars
```

## Support & Contribution

### Getting Help

- Review module documentation in each module's README
- Check Terraform GitHub Provider documentation
- Review examples in terraform.tfvars.example

### Contributing

- Follow Terraform style guide
- Run `terraform fmt` before committing
- Add tests for new modules
- Update documentation with changes

## References

- [Terraform GitHub Provider Documentation](https://registry.terraform.io/providers/integrations/github/latest/docs)
- [GitHub Advanced Security Documentation](https://docs.github.com/en/enterprise-cloud@latest/get-started/learning-about-github/about-github-advanced-security)
- [GitHub Copilot Documentation](https://docs.github.com/en/copilot)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
