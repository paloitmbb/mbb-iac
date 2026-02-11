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

**Repository Admins** (required)
- Comma-separated GitHub usernames
- Must be valid GitHub users in the organization
- These users will have admin access
- Example: `john-doe, jane-smith, bob-wilson`

#### Configuration Options

**Visibility** (required)
- `private` - Only organization members (default, recommended)
- `internal` - All organization members can see
- `public` - Publicly visible (use with caution)

**Target Environment** (required)
- `dev` - Development environment (recommended for new repos)
- `staging` - Staging environment
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
- ☑️ I understand that this repository will be created with 4 default teams
- ☑️ I have listed all required admin users and verified their usernames
- ☑️ I will manage additional team memberships after repository creation

### Step 4: Submit the Issue

Click **"Submit new issue"**

## What Happens Next?

### Automatic Validation (30 seconds)

The workflow will automatically:
1. ✅ Validate repository name format
2. ✅ Check admin usernames exist
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
1. ✅ Create repository with your configuration
2. ✅ Create 4 teams with proper permissions
3. ✅ Add specified admins to admin team
4. ✅ Update infrastructure as code
5. 📝 Post success message with links
6. ✅ Close the issue

## Your New Repository

### Included Teams

Four teams are automatically created:

| Team Name | Permission | Who Should Join |
|-----------|------------|-----------------|
| `{repo-name}-admin` | Admin | Tech leads, project managers |
| `{repo-name}-dev` | Write | Developers |
| `{repo-name}-test` | Write | QA engineers, testers |
| `{repo-name}-prod` | Maintain | DevOps, release managers |

**Note:** Only admin team is populated automatically. Add members to other teams via GitHub UI.

### Next Steps After Creation

1. **Access your repository**
   - Check the success comment for direct link
   - URL format: `https://github.com/{org}/{repo-name}`

2. **Add team members**
   - Go to repository Settings → Collaborators and teams
   - Or go to Organization → Teams → {team-name} → Members

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
Admins: john-doe, jane-smith
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
Admins: alice-dev, bob-ux
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

### Validation Failed: Admin Users

**Error:** "Invalid usernames: xyz-user"

**Solution:**
- Verify username exists on GitHub
- Check spelling and case (usernames are case-sensitive)
- Ensure user is part of the organization
- Separate multiple usernames with commas
- ✅ Good: `john-doe, jane-smith`
- ❌ Bad: `john doe`, `@john-doe`

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
A: Request in "Additional Notes" field. Custom permissions can be configured during approval.

**Q: Can I delete a repository?**
A: Contact DevSecOps team. Repository deletion requires approval and cleanup.

**Q: What happens to my issue?**
A: Issue is closed automatically after repository creation with success message and links.

---

**Need more information?** See the [Implementation Plan](./02-AUTOMATED_REPO_WORKFLOW_PLAN.md) for technical details.
