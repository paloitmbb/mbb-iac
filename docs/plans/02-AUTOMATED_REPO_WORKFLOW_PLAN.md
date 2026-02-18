# Automated Repository Creation Workflow - Implementation Plan

**Created:** 11 February 2026  
**Last Updated:** 18 February 2026  
**Owner:** DevSecOps Team  
**Status:** Implemented

---

> **⚠️ IMPORTANT UPDATE (Current Implementation):**  
> The implementation has been modified from the original plan:
>
> - **No teams are created** - users specify existing teams that will have access to the repository
> - **Teams are specified** as comma-separated entries in the issue form
> - **Team validation** ensures all specified teams exist in the organization before approval
> - **Team permissions** are assigned based on the teams' existing roles
> - Users must use existing organization teams, not create new ones
>
> This document retains the original plan for reference. See [02-IMPLEMENTATION_SUMMARY.md](./02-IMPLEMENTATION_SUMMARY.md) for the current architecture.

---

> **🔄 RECENT UPDATES (February 2026):**
>
> **Backend Migration:**
> - ✅ Migrated dev environment to **Azure Blob Storage** backend
> - ✅ Removed HTTP backend (GitHub Releases) fallback logic
> - ✅ Simplified scripts to Azure-only backend
>
> **OIDC Authentication:**
> - ✅ Implemented **OIDC authentication** for Azure (secretless)
> - ✅ Removed `ARM_CLIENT_SECRET` requirement from workflows
> - ✅ Updated all Terraform workflows with `azure/login@v2`
> - ✅ Reduced GitHub secrets from 4 to 3
>
> **Backend Configuration:**
> - Storage Account: `mbbtfstate` (resource group: `mbb`)
> - Container: `tfstate`
> - State file: `github.terraform.tfstate`
>
> See [AZURE_BACKEND_SETUP.md](../../AZURE_BACKEND_SETUP.md) for Azure backend details.

---

## Executive Summary

Implement a GitHub issue-driven automated workflow that allows end users to request new repository creation through a structured issue form. The workflow requires approval from paloitmbb-devsecops team members and automatically provisions repositories with access granted to existing organization teams specified in the request.

---

## Architecture Overview

```
┌─────────────────┐
│  User Creates   │
│  GitHub Issue   │
└────────┬────────┘
         │
         ▼
┌─────────────────────────┐
│  Workflow: Validate &   │
│  Post Issue Summary     │
│  - Validate repo name   │
│  - Validate teams exist │
│  - Check GitHub repos   │
│  - Check YAML file      │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│  Environment Approval   │
│  (paloitmbb-devsecops)  │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│  Update YAML Files:     │
│  - repositories.yaml    │
│  (with team access)     │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│  Create Pull Request    │
│  (with repo config)     │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│  Manual PR Review       │
│  & Merge to main        │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│  Workflow: Terraform    │
│  Apply (on PR merge)    │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│  Terraform Apply        │
│  - Create Repo          │
│  - Grant Team Access    │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│  Post Success/Failure   │
│  Comment to Issue       │
│  & Close Issue          │
└─────────────────────────┘
```

---

## Phase 1: Team Access Configuration

### 1.1 Team Access via Repository Module

**Approach:** Instead of creating new teams, the workflow will grant access to existing teams specified by the user. The `github-repository` module already supports team access configuration through the `teams` parameter.

**Existing Module Support:**

The `modules/github-repository/main.tf` already includes:

```hcl
resource "github_team_repository" "this" {
  for_each = {
    for team in var.teams : team.team => team
  }

  team_id    = each.value.team
  repository = github_repository.this.name
  permission = each.value.permission
}
```

**Configuration Example:**

```yaml
# data/repositories.yaml
repositories:
  - name: mbb-payment-service
    description: "Payment processing service"
    visibility: private
    teams:
      - team: platform-team
        permission: admin
      - team: developers
        permission: push
      - team: qa-team
        permission: push
```

---

## Phase 2: Team Validation

### 2.1 Team Existence Validation

**Approach:** The workflow will validate that all teams specified in the repository request exist in the organization before proceeding with repository creation.

**Validation Requirements:**

- Teams must exist in the organization
- Team names must be valid GitHub team slugs
- Users must have permission to view the teams

### 2.2 Team Permission Mapping

**Supported Permissions:**

The workflow will support the following GitHub repository permissions:

| Permission | Description                                     |
| ---------- | ----------------------------------------------- |
| `pull`     | Read access - can pull but not push             |
| `triage`   | Can manage issues and PRs without write access  |
| `push`     | Write access - can push to repository           |
| `maintain` | Maintain access - can manage repo without admin |
| `admin`    | Full administrative access                      |

**Default Permission:** If not specified, teams will be granted `push` (write) permission.

### 2.3 Repository YAML Structure with Teams

**File:** `data/repositories.yaml` (example entry)

```yaml
repositories:
  - name: mbb-payment-service
    description: "Payment processing service"
    visibility: private
    features:
      has_issues: true
      has_projects: true
      has_wiki: false
    default_branch: main
    topics:
      - payment
      - api
      - java
    teams:
      - team: platform-team
        permission: admin
      - team: backend-developers
        permission: push
      - team: qa-team
        permission: push
```

## Phase 3: Issue Template with Team Access

### 3.1 Updated Issue Template

### 3.1 Updated Issue Template

**Design Philosophy:** Keep the form minimal, use defaults from existing repositories, and allow users to specify existing teams for access.

**File:** `.github/ISSUE_TEMPLATE/new-repository.yml`

```yaml
name: New Repository Request
description: Request creation of a new GitHub repository with access granted to existing teams
title: "[REPO REQUEST] "
labels: ["repo-request", "pending-review"]
assignees:
  - devsecops-team

body:
  - type: markdown
    attributes:
      value: |
        ## Repository Request Form
        Please fill out this form to request a new repository. Your request will be reviewed by the DevSecOps team.

        **Note:** The repository will be created with:
        - Access granted to existing teams you specify
        - Default settings based on existing repository configurations

        **Default Configuration:**
        All settings not specified in this form (visibility, features, security, topics, etc.) will use default values from existing repository configurations in the organization.

  - type: input
    id: repo-name
    attributes:
      label: Repository Name
      description: Name of the new repository (lowercase, hyphens only, no spaces)
      placeholder: "mbb-new-service"
    validations:
      required: true

  - type: input
    id: teams
    attributes:
      label: Team Access
      description: Comma-separated list of existing team slugs that should have access to this repository. Teams must already exist in the organization. (Team existence will be validated)
      placeholder: "platform-team, backend-developers, qa-team"
    validations:
      required: true

  - type: dropdown
    id: tech-stack
    attributes:
      label: Tech Stack
      description: Primary technology stack for this repository
      options:
        - React
        - Java Springboot
        - NodeJS
        - Python
        - Others (specify below)
    validations:
      required: true

  - type: input
    id: tech-stack-other
    attributes:
      label: Other Tech Stack
      description: If you selected "Others", please specify the tech stack
      placeholder: "e.g., Ruby on Rails, Go, .NET"

  - type: textarea
    id: justification
    attributes:
      label: Business Justification
      description: Explain why this repository is needed and how it will be used
      placeholder: |
        - Business need:
        - Expected usage:
        - Impact:
    validations:
      required: true

  - type: dropdown
    id: default-branch
    attributes:
      label: Default Branch Name
      options:
        - main
        - master
        - develop
      default: 0
    validations:
      required: true

  - type: checkboxes
    id: terms
    attributes:
      label: Acknowledgment
      description: Please confirm you understand the following
      options:
        - label: I understand that this repository will be created with access granted to the teams I specified
          required: true
        - label: I understand that the teams I specify must already exist in the organization
          required: true
        - label: I understand that repository settings will use organization defaults unless otherwise specified
          required: true
```

title: "[REPO REQUEST] "
labels: ["repo-request", "pending-review"]
assignees:

- devsecops-team

body:

- type: markdown
  attributes:
  value: | ## Repository Request Form
  Please fill out this form to request a new repository. Your request will be reviewed by the DevSecOps team.

      **Note:** The repository will be created with:
      - 3 teams: `{repo-name}-dev`, `{repo-name}-test`, `{repo-name}-prod`
      - Default settings based on existing repository configurations
      - Team maintainers (admins) will manage team membership

      **Default Configuration:**
      All settings not specified in this form (visibility, features, security, topics, etc.) will use default values from existing repository configurations in the organization.

- type: input
  id: repo-name
  attributes:
  label: Repository Name
  description: Name of the new repository (lowercase, hyphens only, no spaces)
  placeholder: "mbb-new-service"
  validations:
  required: true

- type: input
  id: admins
  attributes:
  label: Team Maintainers
  description: Comma-separated GitHub usernames who will become team maintainers (can manage team membership). Leave empty to make yourself the maintainer. (Usernames will be validated)
  placeholder: "john-doe, jane-smith, bob-jones"
  validations:
  required: false

- type: dropdown
  id: tech-stack
  attributes:
  label: Tech Stack
  description: Primary technology stack for this repository
  options: - React - Java Springboot - NodeJS - Python - Others (specify below)
  validations:
  required: true

- type: input
  id: tech-stack-other
  attributes:
  label: Other Tech Stack
  description: If you selected "Others", please specify the tech stack
  placeholder: "e.g., Ruby on Rails, Go, .NET"

- type: textarea
  id: justification
  attributes:
  label: Business Justification
  description: Explain why this repository is needed and how it will be used
  placeholder: | - Business need: - Expected usage: - Impact:
  validations:
  required: true

- type: dropdown
  id: default-branch
  attributes:
  label: Default Branch Name
  options: - main - master - develop
  default: 0
  validations:
  required: true

- type: checkboxes
  id: terms
  attributes:
  label: Acknowledgment
  description: Please confirm you understand the following
  options: - label: I understand that this repository will be created with 3 default teams (dev, test, prod)
  required: true - label: I understand that team maintainers manage team membership and can add/remove members
  required: true - label: I understand that repository settings will use organization defaults unless otherwise specified
  required: true

````

**Simplified Form Fields:**

- **Repository Name** (required)
- **Team Access** (required - comma-separated existing team slugs)
- **Tech Stack** (required)
- **Business Justification** (required)
- **Default Branch** (required - dropdown: main/master/develop)
- **Acknowledgement** (required checkboxes)

**Default Values Strategy:**
All other repository settings (visibility, features, security, topics, variables, etc.) will use default values from `data/defaults.yaml`. This provides:

- Explicit and centralized default configuration
- Consistency across repositories
- Reduced form complexity
- Easier maintenance
- Ability to override defaults via manual YAML edits after creation

### 3.2 Default Values Configuration

The workflow will use the first repository in `repositories.yaml` as a template for default values:

```yaml
# data/repositories.yaml - First entry used as defaults
repositories:
  - name: mbb-web-portal # Template repository
    description: Customer-facing web portal for Paloitmbb services
    visibility: private
    features:
      has_issues: true
      has_projects: true
      has_wiki: false
    default_branch: main
    topics:
      - frontend
      - react
      - typescript
      - customer-portal
    security:
      enable_vulnerability_alerts: true
      enable_advanced_security: false
      enable_secret_scanning: false
      enable_secret_scanning_push_protection: false
      enable_dependabot_alerts: true
      enable_dependabot_security_updates: true
    variables:
      ENVIRONMENT:
        value: production
      API_BASE_URL:
        value: https://api.paloitmbb.com
```

The workflow will:

1. Load the first repository from `repositories.yaml`
2. Use its configuration as default values
3. Override only the fields from the issue form:
   - `name` - from issue
   - `description` - generated from name and tech stack
   - `default_branch` - from issue
   - `topics` - add tech stack to existing topics
4. Keep all other settings from the template

---

## Phase 4: Automated Workflow Implementation

### 4.1 GitHub Environment Setup

**Manual Step:** Create GitHub Environment for approval

1. Go to repository Settings → Environments
2. Create new environment: `repo-creation-approval`
3. Add required reviewers: `paloitmbb-devsecops` team
4. Set deployment branch pattern: `main`

### 4.2 Updated Workflow with Team Validation

**File:** `.github/workflows/repo-request.yml`

```yaml
name: Automated Repository Creation Workflow

on:
  issues:
    types: [opened, labeled]

permissions:
  issues: write
  contents: write
  pull-requests: write

jobs:
  # ============================================================================
  # Job 1: Validate and Parse Issue
  # ============================================================================
  validate-request:
    name: Validate Repository Request
    runs-on: ubuntu-latest
    if: contains(github.event.issue.labels.*.name, 'repo-request')
    outputs:
      repo-name: ${{ steps.parse.outputs.repo-name }}
      tech-stack: ${{ steps.parse.outputs.tech-stack }}
      justification: ${{ steps.parse.outputs.justification }}
      teams: ${{ steps.parse.outputs.teams }}
      default-branch: ${{ steps.parse.outputs.default-branch }}
      validation-passed: ${{ steps.validate.outputs.passed }}

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Parse issue body
        id: parse
        uses: actions/github-script@v7
        with:
          script: |
            const issueBody = context.payload.issue.body;

            // Helper function to extract field value
            function extractField(body, fieldLabel) {
              const regex = new RegExp(`### ${fieldLabel}\\s*\\n\\s*([^\\n#]+)`, 'i');
              const match = body.match(regex);
              return match ? match[1].trim() : '';
            }

            // Extract simplified fields only
            const repoName = extractField(issueBody, 'Repository Name');
            const techStack = extractField(issueBody, 'Tech Stack');
            const techStackOther = extractField(issueBody, 'Other Tech Stack');
            const justification = extractField(issueBody, 'Business Justification');
            const teams = extractField(issueBody, 'Team Access');
            const defaultBranch = extractField(issueBody, 'Default Branch Name');

            // Determine final tech stack
            const finalTechStack = techStack === 'Others (specify below)' ? techStackOther : techStack;

            // Set outputs (only required fields)
            core.setOutput('repo-name', repoName);
            core.setOutput('tech-stack', finalTechStack);
            core.setOutput('justification', justification);
            core.setOutput('teams', teams);
            core.setOutput('default-branch', defaultBranch || 'main');

      - name: Load default values from repositories.yaml
        id: load-defaults
        run: |
          # Load first repository as template
          DEFAULTS=$(yq eval '.repositories[0]' data/repositories.yaml -o json)
          echo "defaults<<EOF" >> $GITHUB_OUTPUT
          echo "$DEFAULTS" >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT

      - name: Validate repository name
        id: validate-name
        run: |
          REPO_NAME="${{ steps.parse.outputs.repo-name }}"

          # Check if repo name matches pattern (lowercase, hyphens, no spaces)
          if [[ ! "$REPO_NAME" =~ ^[a-z0-9-]+$ ]]; then
            echo "error=Repository name must be lowercase with hyphens only" >> $GITHUB_OUTPUT
            echo "valid=false" >> $GITHUB_OUTPUT
            exit 0
          fi

          echo "valid=true" >> $GITHUB_OUTPUT

      - name: Validate team existence
        id: validate-teams
        uses: actions/github-script@v7
        with:
          script: |
            const teamsString = '${{ steps.parse.outputs.teams }}';
            const teamList = teamsString.split(',').map(t => t.trim()).filter(t => t);

            if (teamList.length === 0) {
              core.setOutput('error', 'At least one team must be specified');
              core.setOutput('valid', 'false');
              return;
            }

            const invalidTeams = [];

            // Validate each team exists in organization
            for (const teamSlug of teamList) {
              try {
                await github.rest.teams.getByName({
                  org: context.repo.owner,
                  team_slug: teamSlug
                });
              } catch (error) {
                invalidTeams.push(teamSlug);
              }
            }

            if (invalidTeams.length > 0) {
              core.setOutput('error', `Teams do not exist in organization: ${invalidTeams.join(', ')}`);
              core.setOutput('valid', 'false');
              return;
            }

            core.setOutput('valid', 'true');
            core.setOutput('team-list', JSON.stringify(teamList));

      - name: Check repository existence
        id: check-repo
        uses: actions/github-script@v7
        with:
          script: |
            const repoName = '${{ steps.parse.outputs.repo-name }}';
            try {
              await github.rest.repos.get({
                owner: context.repo.owner,
                repo: repoName
              });
              core.setOutput('exists', 'true');
              core.setOutput('error', `Repository ${repoName} already exists`);
            } catch (error) {
              if (error.status === 404) {
                core.setOutput('exists', 'false');
              } else {
                throw error;
              }
            }

      - name: Check repository in YAML file
        id: check-yaml
        run: |
          REPO_NAME="${{ steps.parse.outputs.repo-name }}"
          
          # Install yq if not available
          if ! command -v yq &> /dev/null; then
            wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
            chmod +x /usr/local/bin/yq
          fi
          
          # Check if repository exists in data/repositories.yaml
          if [ -f "data/repositories.yaml" ]; then
            # Search for the repository name in the YAML file
            REPO_FOUND=$(yq eval ".repositories[] | select(.name == \"$REPO_NAME\") | .name" data/repositories.yaml)
            
            if [ -n "$REPO_FOUND" ]; then
              echo "exists=true" >> $GITHUB_OUTPUT
              echo "error=Repository entry for '$REPO_NAME' already exists in data/repositories.yaml" >> $GITHUB_OUTPUT
            else
              echo "exists=false" >> $GITHUB_OUTPUT
            fi
          else
            echo "exists=false" >> $GITHUB_OUTPUT
          fi

      - name: Consolidate validation
        id: validate
        run: |
          NAME_VALID="${{ steps.validate-name.outputs.valid }}"
          TEAMS_VALID="${{ steps.validate-teams.outputs.valid }}"
          REPO_EXISTS="${{ steps.check-repo.outputs.exists }}"
          YAML_EXISTS="${{ steps.check-yaml.outputs.exists }}"

          if [[ "$NAME_VALID" == "true" && "$TEAMS_VALID" == "true" && "$REPO_EXISTS" != "true" && "$YAML_EXISTS" != "true" ]]; then
            echo "passed=true" >> $GITHUB_OUTPUT
          else
            echo "passed=false" >> $GITHUB_OUTPUT
          fi

      - name: Post validation results
        uses: actions/github-script@v7
        with:
          script: |
            const passed = '${{ steps.validate.outputs.passed }}' === 'true';
            const nameValid = '${{ steps.validate-name.outputs.valid }}' === 'true';
            const teamsValid = '${{ steps.validate-teams.outputs.valid }}' === 'true';
            const repoExists = '${{ steps.check-repo.outputs.exists }}' === 'true';
            const yamlExists = '${{ steps.check-yaml.outputs.exists }}' === 'true';

            let commentBody = '## 🔍 Repository Request Validation\n\n';

            if (passed) {
              commentBody += '✅ **All validations passed!**\n\n';
              commentBody += '### Request Summary\n';
              commentBody += `- **Repository Name:** \`${{ steps.parse.outputs.repo-name }}\`\n`;
              commentBody += `- **Tech Stack:** ${{ steps.parse.outputs.tech-stack }}\n`;
              commentBody += `- **Teams:** ${{ steps.parse.outputs.teams }}\n`;
              commentBody += `- **Default Branch:** ${{ steps.parse.outputs.default-branch }}\n\n`;

              commentBody += '### Teams with Access\n';
              const teamList = '${{ steps.parse.outputs.teams }}'.split(',').map(t => t.trim());
              for (const team of teamList) {
                commentBody += `- \`${team}\` - Existing organization team\n`;
              }
              commentBody += '\n';

              commentBody += '---\n\n';
              commentBody += '⏳ **Awaiting approval from DevSecOps team...**\n';
              commentBody += 'Once approved, the repository will be created with access granted to the specified teams.';
            } else {
              commentBody += '❌ **Validation Failed**\n\n';
              commentBody += '### Errors Found:\n';

              if (!nameValid) {
                commentBody += `- ❌ Repository Name: ${{ steps.validate-name.outputs.error }}\n`;
              }
              if (!teamsValid) {
                commentBody += `- ❌ Teams: ${{ steps.validate-teams.outputs.error }}\n`;
              }
              if (repoExists) {
                commentBody += `- ❌ Repository Already Exists: ${{ steps.check-repo.outputs.error }}\n`;
              }
              if (yamlExists) {
                commentBody += `- ❌ Repository Entry in YAML: ${{ steps.check-yaml.outputs.error }}\n`;
              }

              commentBody += '\n---\n\n';
              commentBody += '⚠️ **Please fix the above errors and create a new issue.**';
            }

            await github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: commentBody
            });

            // Add label based on validation
            if (passed) {
              await github.rest.issues.addLabels({
                issue_number: context.issue.number,
                owner: context.repo.owner,
                repo: context.repo.repo,
                labels: ['validation-passed']
              });
            } else {
              await github.rest.issues.addLabels({
                issue_number: context.issue.number,
                owner: context.repo.owner,
                repo: context.repo.repo,
                labels: ['validation-failed']
              });

              // Close issue if validation failed
              await github.rest.issues.update({
                issue_number: context.issue.number,
                owner: context.repo.owner,
                repo: context.repo.repo,
                state: 'closed'
              });
            }

      - name: Update repositories.yaml with team access
        id: update-repos
        run: |
          REPO_NAME="${{ needs.validate-request.outputs.repo-name }}"
          TEAMS="${{ needs.validate-request.outputs.teams }}"

          # Parse teams from comma-separated list
          IFS=',' read -ra TEAM_ARRAY <<< "$TEAMS"

          # Build teams YAML array
          TEAMS_YAML=""
          for team in "${TEAM_ARRAY[@]}"; do
            team=$(echo "$team" | xargs)  # Trim whitespace
            TEAMS_YAML+="\n      - team: ${team}\n        permission: push"
          done

          # Append to repositories.yaml
          cat >> data/repositories.yaml << EOF

    - name: ${REPO_NAME}
      description: "${{ needs.validate-request.outputs.tech-stack }} repository"
      visibility: private
      features:
        has_issues: true
        has_projects: true
        has_wiki: false
      default_branch: ${{ needs.validate-request.outputs.default-branch }}
      topics:
        - ${{ needs.validate-request.outputs.tech-stack }}
      teams:${TEAMS_YAML}
  EOF

          echo "Successfully updated repositories.yaml with team access"

      - name: Commit changes to main
        run: |
          git add data/repositories.yaml
          git commit -m "feat: ✨ add repository ${{ needs.validate-request.outputs.repo-name }} with team access

          Repository request from issue #${{ github.event.issue.number }}

          - Repository: ${{ needs.validate-request.outputs.repo-name }}
          - Tech Stack: ${{ needs.validate-request.outputs.tech-stack }}
          - Teams: ${{ needs.validate-request.outputs.teams }}

          Closes #${{ github.event.issue.number }}"

          git push origin main

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.5.7

      - name: Terraform Init
        run: |
          ./scripts/init.sh ${{ needs.validate-request.outputs.environment }}
        env:
          GITHUB_TOKEN: ${{ secrets.ORG_GITHUB_TOKEN }}

      - name: Terraform Apply
        id: terraform-apply
        run: |
          ./scripts/apply.sh ${{ needs.validate-request.outputs.environment }} -auto-approve
        env:
          GITHUB_TOKEN: ${{ secrets.ORG_GITHUB_TOKEN }}

      - name: Post success comment
        if: success()
        uses: actions/github-script@v7
        with:
          script: |
            const repoName = '${{ needs.validate-request.outputs.repo-name }}';
            const org = context.repo.owner;
            const teams = '${{ needs.validate-request.outputs.teams }}';

            const commentBody = `## ✅ Repository Created Successfully!

            Your repository has been created and configured.

            ### 🎉 Repository Details
            - **Repository:** [${org}/${repoName}](https://github.com/${org}/${repoName})
            - **Visibility:** private
            - **Default Branch:** ${{ needs.validate-request.outputs.default-branch }}

            ### 👥 Teams with Access
            ${teams.split(',').map(t => `- \`${t.trim()}\` - Existing organization team`).join('\n            ')}

            ### 📋 Next Steps
            1. Visit your repository: https://github.com/${org}/${repoName}
            2. Configure branch protection rules if needed
            3. Start developing! 🚀

            ---
            *Automated by GitHub Actions workflow*`;

            await github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: commentBody
            });

            // Close issue
            await github.rest.issues.update({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              state: 'closed',
              state_reason: 'completed'
            });

            // Add completion label
            await github.rest.issues.addLabels({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              labels: ['completed']
            });

      - name: Post failure comment
        if: failure()
        uses: actions/github-script@v7
        with:
          script: |
            const commentBody = `## ❌ Repository Creation Failed

            There was an error creating the repository. Please check the workflow logs for details.

            ### Error Details
            - **Workflow Run:** [View Logs](https://github.com/${context.repo.owner}/${context.repo.repo}/actions/runs/${context.runId})
            - **Step Failed:** Check the logs above

            ### 🔧 Troubleshooting
            A member of the DevSecOps team will investigate and follow up.

            ---
            *Automated by GitHub Actions workflow*`;

            await github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: commentBody
            });

            // Add failure label
            await github.rest.issues.addLabels({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              labels: ['creation-failed']
            });
```

---

## Phase 5: Implementation Checklist

### 5.1 Pre-Implementation Tasks

- [ ] Review and approve implementation plan
- [ ] Create GitHub PAT with required scopes and add as ORG_GITHUB_TOKEN secret
- [ ] Ensure token has required permissions (`repo`, `read:org`, `admin:org`)
- [ ] Verify Terraform backend is properly configured
- [ ] Backup existing data files (`repositories.yaml`)

### 5.2 Issue Template Enhancement

- [ ] Update `.github/ISSUE_TEMPLATE/new-repository.yml`
- [ ] Add tech stack dropdown with options
- [ ] Add "Others" tech stack input field
- [ ] Add justification textarea
- [ ] Add teams input field for comma-separated team slugs
- [ ] Add acknowledgment checkboxes
- [ ] Test issue template creation

### 5.3 GitHub Environment Setup

- [ ] Create `repo-creation-approval` environment in GitHub settings
- [ ] Add `paloitmbb-devsecops` team as required reviewers
- [ ] Configure deployment branch restrictions to `main`
- [ ] Test approval workflow

### 5.4 Workflow Implementation

**Repository Request Workflow:**

- [ ] Update `.github/workflows/repo-request.yml`
- [ ] Implement validation job with repository name validation
- [ ] Implement team existence validation
- [ ] Implement create-repository job with approval requirement
- [ ] Add YAML file update logic with team access configuration
- [ ] Add success comment with team access details
- [ ] Add failure comment with troubleshooting
- [ ] Close issue on success
- [ ] Add appropriate labels (`completed` or `creation-failed`)
- [ ] Test workflow with sample issue

### 5.5 Testing Plan

**Validation Testing:**

- [ ] **Test 1:** Create test issue with valid data and existing teams
- [ ] **Test 2:** Verify validation passes and comment posted
- [ ] **Test 3:** Test invalid repository name (validation failure)
- [ ] **Test 4:** Test non-existent team names (validation failure)
- [ ] **Test 5:** Test duplicate repository name (validation failure)
- [ ] **Test 6:** Test empty teams field (validation failure)

**Repository Creation Testing:**

- [ ] **Test 7:** Approve workflow and verify repository creation
- [ ] **Test 8:** Verify repository has correct settings
- [ ] **Test 9:** Verify teams have access to repository
- [ ] **Test 10:** Verify team permissions are correct
- [ ] **Test 11:** Verify success comment posted to issue
- [ ] **Test 12:** Verify issue closed with "completed" status
- [ ] **Test 13:** Test terraform failure scenario
- [ ] **Test 14:** Verify failure comment and labels added

**End-to-End Testing:**

- [ ] **Test 15:** Complete end-to-end test in dev environment
- [ ] **Test 16:** Test with single team
- [ ] **Test 17:** Test with multiple teams

### 5.6 Documentation

- [ ] Update main README.md with workflow documentation
- [ ] Create runbook for troubleshooting common issues
- [ ] Document team access management procedures
- [ ] Update project structure documentation
- [ ] Create user guide for repository requesters

### 5.7 Deployment

- [ ] Deploy to dev environment
- [ ] Run full test suite in dev
- [ ] Deploy to staging environment
- [ ] Run smoke tests in staging
- [ ] Deploy to production environment
- [ ] Monitor first few production requests

---

## Phase 6: Rollout Plan

### 6.1 Development Environment (Week 1)

1. **Day 1-2:** Update issue template with team access field
2. **Day 3-4:** Implement team validation logic in workflow
3. **Day 5:** Test validation workflow in dev environment

### 6.2 Workflow Development (Week 2)

1. **Day 1-2:** Create GitHub environment for approval
2. **Day 3-4:** Implement repository creation workflow with team access
3. **Day 5:** Implement success/failure notification logic

### 6.3 Testing Phase (Week 3)

1. **Day 1-2:** Execute test plan in dev environment
2. **Day 3:** Fix identified issues
3. **Day 4-5:** Regression testing and documentation

### 6.4 Staging Deployment (Week 4)

1. **Day 1:** Deploy to staging environment
2. **Day 2-3:** Run full test suite in staging
3. **Day 4-5:** User acceptance testing with DevSecOps team

### 6.5 Production Deployment (Week 5)

1. **Day 1:** Production deployment during maintenance window
2. **Day 2-3:** Monitor first production requests
3. **Day 4-5:** Gather feedback and create iteration backlog

---

## Phase 7: Success Criteria

### 7.1 Functional Requirements

- ✅ Users can create repository requests via GitHub issues
- ✅ Workflow validates all input fields automatically
- ✅ Workflow validates that specified teams exist in the organization
- ✅ DevSecOps team receives approval requests
- ✅ Repositories are created with correct configuration
- ✅ Existing teams are granted access to the repository
- ✅ Success/failure notifications posted to issue
- ✅ YAML data files updated automatically

### 7.2 Non-Functional Requirements

- ✅ Workflow completes within 5 minutes (excluding approval wait time)
- ✅ All operations are idempotent (can be retried safely)
- ✅ Comprehensive error handling and logging
- ✅ Zero manual intervention required after approval
- ✅ Audit trail maintained in Git history
- ✅ Documentation comprehensive and up-to-date

### 7.3 Security Requirements

- ✅ GitHub token permissions follow least privilege principle
- ✅ Approval required from authorized team members only
- ✅ Input validation prevents injection attacks
- ✅ Team existence validated against organization teams
- ✅ All operations logged and auditable

---

## Phase 8: Monitoring and Maintenance

### 8.1 Monitoring

- Monitor workflow success/failure rates via GitHub Actions insights
- Track average time from request to completion
- Monitor Terraform apply success rates
- Alert on consecutive workflow failures

### 8.2 Maintenance Tasks

- **Weekly:** Review failed workflow runs and resolve issues
- **Monthly:** Review and update tech stack options based on usage
- **Quarterly:** Audit team permissions and repository access
- **Annually:** Review and optimize workflow performance

---

## Phase 9: Troubleshooting Guide

### 9.1 Common Issues

| Issue                               | Possible Cause           | Resolution                            |
| ----------------------------------- | ------------------------ | ------------------------------------- |
| Validation fails for valid team     | Team doesn't exist in org | Create team first or use existing team |
| Terraform apply fails               | State lock conflict      | Wait for lock release or force unlock |
| Team access not granted             | Team permissions issue   | Check team exists and has repo access |
| Workflow stuck on approval          | No reviewers available   | Ensure DevSecOps team has members     |
| Invalid team slug error             | Team name format wrong   | Use team slug, not display name       |

### 9.2 Rollback Procedures

If workflow fails after repository creation:

1. **Manual cleanup:**

   ```bash
   # Delete repository
   gh repo delete org/repo-name --yes
   ```

2. **Revert YAML changes:**

   ```bash
   git revert HEAD
   git push origin main
   ```

3. **Remove from Terraform state:**
   ```bash
   terraform state rm 'module.github_repositories["repo-name"]'
   ```

---

## Appendices

### Appendix A: Required GitHub Token

**Secret Name:** `ORG_GITHUB_TOKEN`

**Token Scopes:**
```yaml
Required Scopes:
  - repo (Full control of private repositories)
  - read:org (Read org and team membership)
  - admin:org (Full control of orgs and teams)
```

**Setup:**
1. Create GitHub Personal Access Token (classic)
2. Select required scopes listed above
3. Add as repository secret: `ORG_GITHUB_TOKEN`
4. Token is used for:
   - Team validation (read:org)
   - Terraform provider authentication (repo, admin:org)
   - HTTP backend state management (repo)

### Appendix B: Example Workflow Run

```
Issue Created: #123 "[REPO REQUEST] mbb-payment-service"
    ↓
Validation Job (30 seconds)
    ✅ Repository name valid
    ✅ Teams validated (platform-team, backend-developers)
    ✅ Repository doesn't exist
    📝 Posted summary comment
    ↓
Awaiting Approval (manual step)
    ⏳ DevSecOps team reviews request
    ✅ Team member approves
    ↓
Creation Job (3 minutes)
    ✅ Updated repositories.yaml with team access
    ✅ Committed to main branch
    ✅ Terraform init completed
    ✅ Terraform apply completed
    ✅ Repository created
    ✅ Teams granted access
    📝 Posted success comment
    ✅ Closed issue
    ↓
Complete! Repository Ready 🎉
```

### Appendix C: File Change Summary

**Modified Files:**

- `.github/ISSUE_TEMPLATE/new-repository.yml` (add teams field, update descriptions)
- `.github/workflows/repo-request.yml` (add team validation, update workflow)
- `data/repositories.yaml` (updated by workflow with team access)

**No New Files Required:**
- No new modules needed
- No teams.yaml file needed
- Uses existing github-repository module team access functionality

**Manual Setup:**

- GitHub Environment: `repo-creation-approval`
- Required Reviewers: `paloitmbb-devsecops` team

---

## Sign-off

| Role               | Name            | Signature | Date |
| ------------------ | --------------- | --------- | ---- |
| Plan Author        | DevOps Engineer |           |      |
| Technical Reviewer |                 |           |      |
| Security Reviewer  |                 |           |      |
| Project Approver   |                 |           |      |

---

**End of Implementation Plan**
````
