# How to Request a New Repository

This guide explains how to request a new GitHub repository using our automated workflow.

## Quick Start

1. **Go to Issues** → Click "New Issue"
2. **Select** "New Repository Request" template
3. **Fill out** the form completely
4. **Submit** the issue
5. **Wait** for validation results
6. **Await** DevSecOps team approval
7. **Access** your new repository!

## Step-by-Step Guide

### Step 1: Open a New Issue

Go to: [Create New Issue](../../issues/new/choose)

Select the **"New Repository Request"** template.

### Step 2: Fill Out Required Information

#### Basic Information

**Repository Name** (required)

- Must be lowercase
- Use hyphens for spaces (e.g., `mbb-payment-service`)
- No special characters except hyphens
- Example: `mbb-web-portal`, `mbb-api-gateway`

**Repository Description** (required)

- Brief, clear description of purpose
- Example: "Payment processing API service for mobile banking"

**Tech Stack** (required)

- Select from dropdown: React, Java Springboot, NodeJS, Python, Others
- If "Others", specify in next field

**Business Justification** (required)

- Explain why this repository is needed
- Expected usage and business impact
- Example:
  ```
  - Business need: New mobile payment feature for Q2 2026
  - Expected usage: Backend API for mobile app integration
  - Impact: Enables new revenue stream, serves 100k+ users
  ```

**Team Access** (required)

- Comma-separated existing team slugs
- Teams must already exist in the organization
- Teams will be granted write access to the repository
- You can find available teams in the organization's Teams page
- Example: `platform-team, backend-developers, qa-team`

#### Configuration Options

**Visibility** (required)

- `private` - Only organization members (default, recommended)
- `internal` - All organization members can see
- `public` - Publicly visible (use with caution)

**Target Environment** (required)

- `dev` - Development environment (recommended for new repos)
- `production` - Production environment

**Repository Features**
Select features you want enabled:

- ☑️ Enable Issues - For bug tracking and feature requests
- ☑️ Enable Projects - For project management boards
- ☑️ Enable Wiki - For documentation

**Security Features**
Select security features (GHAS requires license):

- ☑️ Enable Vulnerability Alerts - Free, recommended
- ☑️ Enable Dependabot Alerts - Free, recommended
- ☑️ Enable Dependabot Security Updates - Free, recommended
- ☑️ Enable Advanced Security (GHAS) - Requires license
- ☑️ Enable Secret Scanning - Requires GHAS
- ☑️ Enable Secret Scanning Push Protection - Requires GHAS

**Repository Topics**

- Comma-separated tags for discovery
- Example: `backend, api, microservices, nodejs`

**Default Branch Name**

- `main` - Recommended, modern default
- `master` - Legacy default
- `develop` - Development workflow

### Step 3: Acknowledgment

You must check all boxes to confirm:

- ☑️ I understand that specified teams must exist in the organization
- ☑️ I understand that only existing teams can be granted access
- ☑️ I will verify team slugs are correct before submitting

### Step 4: Submit the Issue

Click **"Submit new issue"**

## What Happens Next?

### Automatic Validation (30 seconds)

The workflow will automatically:

1. ✅ Validate repository name format
2. ✅ Check specified teams exist in organization
3. ✅ Verify repository doesn't already exist
4. 📝 Post validation results as comment

**If validation passes:**

- Issue labeled as `validation-passed`
- Workflow waits for DevSecOps approval

**If validation fails:**

- Issue labeled as `validation-failed`
- Issue automatically closed
- Comment explains what needs fixing
- Create a new issue with corrections

### Manual Approval (varies)

DevSecOps team will:

1. Review your request and justification
2. Verify business need
3. Approve or request changes

**Approval typically takes:** 1-2 business days

### Automatic Creation (3-5 minutes)

After approval, the workflow will:

1. ✅ Create pull request with repository configuration
2. ✅ Include team access specifications
3. ✅ Update infrastructure as code
4. 📝 Post PR link to issue
5. ⏳ Wait for PR review and merge
6. 🚀 Run Terraform to create repository and grant team access

## Your New Repository

### Team Access

The teams you specified will be granted access:

**Default Permission:** `push` (write access)

**Note:** Teams must be created and managed separately through GitHub's organization settings. The workflow only grants access to existing teams.

### Next Steps After Creation

1. **Access your repository**
   - Check the success comment for direct link
   - URL format: `https://github.com/{org}/{repo-name}`

2. **Verify team access**
   - Go to repository Settings → Collaborators and teams
   - Confirm specified teams have access

3. **Configure branch protection** (optional)
   - Settings → Branches → Add rule
   - Recommended for `main` branch

4. **Start developing!**
   - Clone repository
   - Add initial code
   - Set up CI/CD pipelines

## Examples

### Example 1: Backend API Service

```yaml
Repository Name: mbb-payment-api
Description: Payment processing API for mobile banking app
Tech Stack: Java Springboot
Justification:
  - Business need: New payment feature for Q2 2026
  - Expected usage: Backend API for mobile integration
  - Impact: Critical path for new revenue stream
Team Access: platform-team, backend-developers
Visibility: private
Environment: dev
Features: ✓ Issues, ✓ Projects
Security: ✓ All Dependabot features, ✓ GHAS
Topics: backend, api, payment, springboot
Default Branch: main
```

### Example 2: Frontend Application

```yaml
Repository Name: mbb-customer-portal
Description: Customer-facing web portal for account management
Tech Stack: React
Justification:
  - Business need: Replace legacy customer portal
  - Expected usage: Public-facing web application
  - Impact: Improved customer experience, 50k+ daily users
Team Access: frontend-team, qa-team
Visibility: private
Environment: dev
Features: ✓ Issues, ✓ Projects, ✓ Wiki
Security: ✓ Vulnerability Alerts, ✓ Dependabot
Topics: frontend, react, web-portal, customer-facing
Default Branch: main
```

## Common Issues and Solutions

### Validation Failed: Repository Name

**Error:** "Repository name must be lowercase with hyphens only"

**Solution:**

- Use only lowercase letters (a-z)
- Use numbers (0-9)
- Use hyphens (-) to separate words
- No spaces, underscores, or special characters
- ✅ Good: `mbb-payment-service`
- ❌ Bad: `MBB_Payment_Service`, `mbb payment service`

### Validation Failed: Team Access

**Error:** "Team 'xyz-team' does not exist in organization"

**Solution:**

- Verify team exists in the organization
- Check spelling and case (team slugs are case-sensitive)
- Find available teams: Organization → Teams
- Separate multiple team slugs with commas
- Team slugs use hyphens, not spaces
- ✅ Good: `platform-team, backend-developers`
- ❌ Bad: `Platform Team`, `@platform-team`, `nonexistent-team`

### Validation Failed: Repository Exists

**Error:** "Repository {name} already exists"

**Solution:**

- Choose a different, unique name
- Check existing repositories: [Organization Repos](../../repositories)
- Add more specific suffix: `mbb-payment-api-v2`

## Need Help?

### For Repository Requests

- **Slack:** #devsecops-support
- **Email:** devsecops@maybank.com
- **Issue:** Tag `@paloitmbb-devsecops` in your issue

### For Technical Issues

- **Documentation:** See [Technical Guidelines](../../.github/instructions/tech.instructions.md)
- **Terraform Issues:** See [Project Structure](../../.github/instructions/structure.instructions.md)
- **Workflow Issues:** Check [GitHub Actions](../../actions)

## FAQs

**Q: How long does the process take?**
A: Validation is instant. Approval typically 1-2 business days. Creation takes 3-5 minutes after approval.

**Q: Can I request multiple repositories at once?**
A: Create separate issues for each repository. This ensures proper tracking and approval.

**Q: Who can request a repository?**
A: Any organization member can request. All requests require DevSecOps approval.

**Q: Can I modify settings after creation?**
A: Yes, but some changes require updating Terraform configuration. Contact DevSecOps team.

**Q: What if I need different team permissions?**
A: Default permission is 'push' (write access). Custom permissions can be configured after repository creation by updating the YAML configuration.

**Q: How do I create a new team for my repository?**
A: Teams must be created separately through GitHub's organization settings. Once created, you can request access in a new repository request or update existing repository configuration.

**Q: Can I specify team permissions in the request?**
A: Currently, all teams are granted 'push' (write) permission by default. For custom permissions (pull, maintain, admin), contact DevSecOps team after creation.

**Q: Can I delete a repository?**
A: Contact DevSecOps team. Repository deletion requires approval and cleanup.

**Q: What happens to my issue?**
A: Issue is closed automatically after repository creation with success message and links.

---

**Need more information?** See the [Implementation Plan](./02-AUTOMATED_REPO_WORKFLOW_PLAN.md) for technical details.
