# Paloitmbb GitHub Infrastructure as Code

Terraform project for managing GitHub organization, repositories, and GitHub Advanced Security (GHAS) configurations.

## Project Structure

```
mbb-iac/
├── modules/                 # Reusable Terraform modules
│   ├── github-organization/ # Organization settings
│   ├── github-repository/   # Repository management
│   └── github-security/     # GHAS configuration
├── environments/            # Environment-specific configs
│   ├── dev/
│   ├── staging/
│   └── production/
├── scripts/                 # Helper scripts
└── .github/                 # GitHub workflows and templates
```

## Features

- 🏢 **Organization Management**: Centralized organization settings and policies
- 📦 **Repository Management**: Standardized repository creation and configuration
- 🔒 **Security**: GitHub Advanced Security (GHAS) integration
- 🔄 **GitOps**: Automated repository creation via GitHub Issues
- 🌍 **Multi-Environment**: Separate configurations for dev, staging, and production
- ☁️ **Flexible Backend**: Azure Storage (dev) and GitHub Releases (staging/production)

## Prerequisites

- Terraform >= 1.14.5
- GitHub organization with admin access
- GitHub Personal Access Token or App with appropriate permissions:
  - `repo` - Full control of repositories
  - `admin:org` - Full control of organizations
  - `workflow` - Update GitHub Actions workflows

## Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd mbb-iac
```

### 2. Configure Authentication

#### For GitHub Resources

```bash
export GITHUB_TOKEN="your-github-token"
```

#### For Backend (Dev Environment uses Azure)

**GitHub Actions**: Uses OIDC authentication (no secrets required)
- Configured via `azure/login@v2` action in workflows
- Requires federated credentials setup in Azure AD

**Local Development**:

```bash
# Option 1: Using Azure Storage Account Access Key
export ARM_ACCESS_KEY="your-storage-account-access-key"

# Option 2: Using Service Principal (with OIDC)
export ARM_CLIENT_ID="your-client-id"
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"
export ARM_USE_OIDC=true

# Option 3: Using Azure CLI
az login
```

**Note**: GitHub Actions workflows use OIDC authentication for secretless Azure login. No `ARM_CLIENT_SECRET` is needed in CI/CD.

### 3. Configure Backend

**Dev Environment**: Uses Azure Blob Storage for state management.

The dev environment backend is already configured in `environments/dev/backend.tfvars`:

```hcl
resource_group_name  = "mbb"
storage_account_name = "mbbtfstate"
container_name       = "tfstate"
key                  = "github.terraform.tfstate"
```

See [AZURE_BACKEND_SETUP.md](AZURE_BACKEND_SETUP.md) for detailed Azure backend setup instructions.

**Staging/Production Environments**: Use GitHub Releases for state management (HTTP backend).

Edit `environments/<env>/backend.tfvars` with your GitHub organization details:

```hcl
# Replace 'your-org' with your GitHub organization name
address        = "https://github.com/your-org/mbb-iac/releases/download/state-<env>/terraform.tfstate"
lock_address   = "https://api.github.com/repos/your-org/mbb-iac/git/refs/locks/<env>"
unlock_address = "https://api.github.com/repos/your-org/mbb-iac/git/refs/locks/<env>"
username       = "terraform"
# password set via TF_HTTP_PASSWORD environment variable (uses GITHUB_TOKEN)
```

See [HTTP_BACKEND_SETUP.md](HTTP_BACKEND_SETUP.md) for GitHub backend setup instructions.

### 4. Initialize Terraform

```bash
./scripts/init.sh dev
```

### 5. Plan Changes

```bash
./scripts/plan.sh dev
```

### 6. Apply Changes

```bash
./scripts/apply.sh dev
```

## Usage

### Managing Repositories

You can manage repositories using either approach:

#### Option 1: YAML Data File (Recommended for many repositories)

Define repositories in `data/repositories.yaml`:

```yaml
repositories:
  - name: my-service
    description: My Service
    visibility: private
    features:
      has_issues: true
      has_projects: true
      has_wiki: false
    security:
      enable_advanced_security: true
      enable_secret_scanning: true
      # ...
```

Leave `repositories = []` in your environment tfvars file. Terraform will automatically load from the YAML file.

See [data/README.md](data/README.md) for detailed documentation.

#### Option 2: Tfvars File (Traditional approach)

Edit `environments/<env>/terraform.tfvars` to add repositories:

```hcl
repositories = [
  {
    name        = "my-service"
    description = "My Service"
    visibility  = "private"
    features = {
      has_issues   = true
      has_projects = true
      has_wiki     = false
    }
    security = {
      enable_advanced_security = true
      enable_secret_scanning   = true
      # ...
    }
  }
]
```

**Note**: If repositories are defined in tfvars, the YAML file is ignored. Choose the approach that works best for your team.

### GitOps Workflow

Create repositories via GitHub Issues:

1. Go to **Issues** → **New Issue**
2. Select **New Repository Request** template
3. Fill in repository details and specify existing teams
4. Submit issue
5. Validation runs automatically (checks team existence)
6. DevSecOps team approves request
7. Automated PR is created with configuration
8. Review and merge PR
9. Run Terraform to create repository and grant team access

See [How to Request a Repository](docs/HOW_TO_REQUEST_REPOSITORY.md) for detailed instructions.

## Scripts

| Script           | Description                             |
| ---------------- | --------------------------------------- |
| `init.sh [env]`  | Initialize Terraform for an environment |
| `plan.sh [env]`  | Run Terraform plan                      |
| `apply.sh [env]` | Apply Terraform changes                 |
| `validate.sh`    | Validate all Terraform configurations   |

## Modules

### github-organization

Manages organization-level settings.

[Documentation](modules/github-organization/README.md)

### github-repository

Creates and configures repositories with branch protection, team access, and webhooks.

[Documentation](modules/github-repository/README.md)

### github-security

Manages GHAS features including secret scanning, Dependabot, and code scanning.

[Documentation](modules/github-security/README.md)

## Security Best Practices

- ✅ Never commit secrets or tokens to version control
- ✅ Use environment variables for sensitive data
- ✅ Enable state encryption at rest
- ✅ Use state locking to prevent concurrent modifications
- ✅ Review all Terraform plans before applying
- ✅ Require PR reviews for production changes
- ✅ Enable GHAS for all repositories
- ✅ Regularly audit security configurations

## CI/CD

This project includes GitHub Actions workflows for:

- **Terraform Plan**: Runs on pull requests
- **Terraform Apply**: Runs on merge to main
- **Repository Requests**: Automates repository creation via issues

## Troubleshooting

### Authentication Errors

Ensure your `GITHUB_TOKEN` has the required permissions:

```bash
export GITHUB_TOKEN="ghp_..."
```

### State Lock Errors

If state is locked, identify the lock ID and force unlock:

```bash
terraform force-unlock <lock-id>
```

### Backend Configuration

The project supports multiple backend types:

- **Dev Environment**: Uses Azure Blob Storage for state management. See [AZURE_BACKEND_SETUP.md](AZURE_BACKEND_SETUP.md) for setup instructions.
- **Staging/Production**: Use HTTP backend with GitHub Releases. See [HTTP_BACKEND_SETUP.md](HTTP_BACKEND_SETUP.md) for setup instructions.

Verify backend is properly configured:

```bash
terraform init -backend-config=environments/<env>/backend.tfvars -reconfigure
```

## Contributing

1. Create a feature branch
2. Make changes
3. Run `./scripts/validate.sh`
4. Submit a pull request
5. Ensure CI checks pass

## Support

For questions or issues:

- Review [PROJECT_CREATION_PLAN.md](PROJECT_CREATION_PLAN.md) for detailed documentation
- Check [HTTP_BACKEND_SETUP.md](HTTP_BACKEND_SETUP.md) for backend configuration
- Check module README files
- Contact the platform team

## License

Internal use only - Paloitmbb

## References

- [Terraform GitHub Provider](https://registry.terraform.io/providers/integrations/github/latest/docs)
- [GitHub Advanced Security](https://docs.github.com/en/enterprise-cloud@latest/get-started/learning-about-github/about-github-advanced-security)
