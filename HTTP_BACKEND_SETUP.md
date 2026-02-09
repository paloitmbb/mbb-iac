# HTTP Backend with GitHub Releases Setup Guide

This project uses GitHub Releases as the backend for Terraform state storage via the HTTP backend protocol.

## How It Works

### State Storage

- Terraform state files are stored as assets in GitHub Releases
- Each environment (dev, staging, production) has its own release tag
- State is retrieved via HTTPS from GitHub Releases
- State is pushed via GitHub API with authentication

### State Locking

- State locking is implemented using GitHub Git references API
- Locks are created as Git refs under `refs/locks/{environment}`
- This prevents concurrent Terraform operations

## Initial Setup

### 1. Update Backend Configuration

Edit the backend configuration files for each environment to use your GitHub organization name:

**environments/dev/backend.tfvars**

```hcl
address        = "https://github.com/YOUR-ORG/mbb-iac/releases/download/state-dev/terraform.tfstate"
lock_address   = "https://api.github.com/repos/YOUR-ORG/mbb-iac/git/refs/locks/dev"
unlock_address = "https://api.github.com/repos/YOUR-ORG/mbb-iac/git/refs/locks/dev"
username       = "terraform"
```

Replace `YOUR-ORG` with your actual GitHub organization name.

### 2. Create Initial State Releases

Before running `terraform init`, you need to create the initial release tags:

```bash
# For dev environment
git tag state-dev
git push origin state-dev

# For staging environment
git tag state-staging
git push origin state-staging

# For production environment
git tag state-production
git push origin state-production
```

Alternatively, create them via GitHub UI or API.

### 3. Set Authentication

The HTTP backend requires authentication via the `TF_HTTP_PASSWORD` environment variable:

```bash
export GITHUB_TOKEN="your-github-token"
export TF_HTTP_PASSWORD="$GITHUB_TOKEN"
```

Or let the init script handle it automatically:

```bash
export GITHUB_TOKEN="your-github-token"
./scripts/init.sh dev  # Automatically sets TF_HTTP_PASSWORD
```

### 4. Initialize Terraform

```bash
./scripts/init.sh dev
```

The first time you run this, Terraform will:

1. Initialize the HTTP backend
2. Create a new state file
3. Upload it to the GitHub Release as an asset

## GitHub Token Requirements

Your GitHub token needs the following permissions:

- `repo` - Full control of repositories (for state storage and retrieval)
- `admin:org` - Full control of organizations (for managing GitHub resources)
- `workflow` - Update GitHub Actions workflows

## State Operations

### Viewing State

```bash
# Download state file
curl -L -H "Authorization: token $GITHUB_TOKEN" \
  "https://github.com/YOUR-ORG/mbb-iac/releases/download/state-dev/terraform.tfstate" \
  -o terraform.tfstate

# View state
terraform show
```

### Manual State Upload

```bash
# If you need to manually upload state
gh release upload state-dev terraform.tfstate --clobber
```

### State Backup

State history is automatically maintained through GitHub Release asset versions and git history.

## Advantages

✅ **No Cloud Infrastructure**: No need for S3 buckets or cloud storage  
✅ **GitHub Native**: Everything stays in GitHub ecosystem  
✅ **Version Control**: State versions tracked in releases  
✅ **Access Control**: Uses GitHub repository permissions  
✅ **Free**: No additional costs for storage  
✅ **Simple**: No additional services to configure

## Limitations

⚠️ **Performance**: Slightly slower than dedicated state backends  
⚠️ **Size Limits**: GitHub Release assets limited to 2GB  
⚠️ **Rate Limits**: Subject to GitHub API rate limits  
⚠️ **Manual Setup**: Requires initial release tags

## Troubleshooting

### Error: "404 Not Found" during init

**Cause**: Release tag doesn't exist yet  
**Solution**: Create the release tag as shown in step 2

### Error: "401 Unauthorized"

**Cause**: Missing or invalid GitHub token  
**Solution**: Ensure `GITHUB_TOKEN` is set and valid:

```bash
echo $GITHUB_TOKEN
gh auth status
```

### Error: "Failed to lock state"

**Cause**: State is already locked or lock ref exists  
**Solution**: Force unlock (use with caution):

```bash
# Via API
curl -X DELETE \
  -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/YOUR-ORG/mbb-iac/git/refs/locks/dev"

# Or via Terraform
terraform force-unlock <lock-id>
```

### Error: "File too large"

**Cause**: State file exceeds GitHub's asset size limits  
**Solution**: Consider:

- Splitting into multiple workspaces
- Using state filtering
- Migrating to Terraform Cloud or another backend

## Migration from S3

If migrating from S3 backend:

1. Update `versions.tf` to use `http` backend
2. Update all `backend.tfvars` files
3. Initialize with existing state:

```bash
terraform init -migrate-state -backend-config=backend.tfvars
```

4. Confirm migration when prompted

## Security Best Practices

1. **Token Management**
   - Use short-lived tokens when possible
   - Rotate tokens regularly
   - Use GitHub Apps for better security

2. **Access Control**
   - Limit repository access to authorized users
   - Use branch protection on main branch
   - Enable audit logging

3. **State Encryption**
   - State is encrypted in transit via HTTPS
   - Consider encrypting sensitive values with `sensitive = true`
   - Use external secret management for credentials

4. **Backup Strategy**
   - Regularly backup release assets
   - Maintain multiple environment states
   - Document disaster recovery procedures

## Additional Resources

- [Terraform HTTP Backend Documentation](https://www.terraform.io/docs/backends/types/http.html)
- [GitHub Releases API](https://docs.github.com/en/rest/releases/releases)
- [GitHub Git Database API](https://docs.github.com/en/rest/git/refs)
