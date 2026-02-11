# Automated Repository Creation Workflow - Implementation Plan

**Created:** 11 February 2026  
**Owner:** DevSecOps Team  
**Status:** Implemented

---

> **⚠️ IMPORTANT UPDATE (Current Implementation):**  
> The implementation has been modified from the original plan:
>
> - **3 teams** are created per repository (dev, test, prod) instead of 4
> - **No separate admin team** - removed from the design
> - **Team Maintainers** specified in the issue become maintainers of all 3 teams
> - If **no maintainers specified**, the issue creator becomes the team maintainer
> - Team maintainers can manage team membership via GitHub UI
>
> This document retains the original plan for reference. See [02-IMPLEMENTATION_SUMMARY.md](./02-IMPLEMENTATION_SUMMARY.md) for the current architecture.

---

## Executive Summary

Implement a GitHub issue-driven automated workflow that allows end users to request new repository creation through a structured issue form. The workflow requires approval from paloitmbb-devsecops team members and automatically provisions repositories with associated teams and permissions.

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
│  - teams.yaml           │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│  Commit to main branch  │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│  Terraform Apply        │
│  - Create Repo          │
│  - Create 4 Teams       │
│  - Set Permissions      │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│  GitHub API Call:       │
│  Populate Admin Team    │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│  Post Success/Failure   │
│  Comment to Issue       │
└─────────────────────────┘
```

---

## Phase 1: Terraform Module for Teams

### 1.1 Create Teams Module

**File:** `modules/github-teams/main.tf`

```hcl
terraform {
  required_version = ">= 1.5.7"
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

# Create GitHub team
resource "github_team" "this" {
  name        = var.team_name
  description = var.description
  privacy     = var.privacy

  # Parent team for hierarchical structure (optional)
  parent_team_id = var.parent_team_id
}

# Team repository access
resource "github_team_repository" "this" {
  for_each = toset(var.repositories)

  team_id    = github_team.this.id
  repository = each.value
  permission = var.permission
}
```

**File:** `modules/github-teams/variables.tf`

```hcl
variable "team_name" {
  description = "Name of the GitHub team"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._-]+$", var.team_name))
    error_message = "Team name must contain only alphanumeric characters, hyphens, underscores, and periods."
  }
}

variable "description" {
  description = "Description of the team"
  type        = string
  default     = ""
}

variable "privacy" {
  description = "Privacy level of the team (secret or closed)"
  type        = string
  default     = "closed"

  validation {
    condition     = contains(["secret", "closed"], var.privacy)
    error_message = "Privacy must be either 'secret' or 'closed'."
  }
}

variable "repositories" {
  description = "List of repository names this team has access to"
  type        = list(string)
  default     = []
}

variable "permission" {
  description = "Permission level for team access to repositories"
  type        = string
  default     = "pull"

  validation {
    condition     = contains(["pull", "triage", "push", "maintain", "admin"], var.permission)
    error_message = "Permission must be one of: pull, triage, push, maintain, admin."
  }
}

variable "parent_team_id" {
  description = "ID of parent team for hierarchical structure"
  type        = number
  default     = null
}
```

**File:** `modules/github-teams/outputs.tf`

```hcl
output "team_id" {
  description = "The ID of the created team"
  value       = github_team.this.id
}

output "team_name" {
  description = "The name of the created team"
  value       = github_team.this.name
}

output "team_slug" {
  description = "The slug of the created team"
  value       = github_team.this.slug
}

output "repository_associations" {
  description = "Map of repository associations"
  value = {
    for repo in var.repositories : repo => {
      team_id    = github_team.this.id
      permission = var.permission
    }
  }
}
```

**File:** `modules/github-teams/versions.tf`

```hcl
terraform {
  required_version = ">= 1.5.7"
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}
```

**File:** `modules/github-teams/README.md`

````markdown
# GitHub Teams Module

Manages GitHub teams and their repository access permissions.

## Features

- Creates GitHub teams with customizable settings
- Manages team repository access and permissions
- Supports hierarchical team structures
- Configurable privacy levels

## Usage

```hcl
module "admin_team" {
  source = "./modules/github-teams"

  team_name    = "mbb-frontend-admin"
  description  = "Admin team for mbb-frontend repository"
  privacy      = "closed"
  repositories = ["mbb-frontend"]
  permission   = "admin"
}
```
````

## Inputs

| Name           | Description                   | Type         | Default  | Required |
| -------------- | ----------------------------- | ------------ | -------- | -------- |
| team_name      | Name of the GitHub team       | string       | n/a      | yes      |
| description    | Description of the team       | string       | ""       | no       |
| privacy        | Privacy level (secret/closed) | string       | "closed" | no       |
| repositories   | List of repository names      | list(string) | []       | no       |
| permission     | Permission level              | string       | "pull"   | no       |
| parent_team_id | Parent team ID                | number       | null     | no       |

## Outputs

| Name                    | Description                    |
| ----------------------- | ------------------------------ |
| team_id                 | The ID of the created team     |
| team_name               | The name of the created team   |
| team_slug               | The slug of the created team   |
| repository_associations | Map of repository associations |

````

---

## Phase 2: DevSecOps Team Creation

### 2.1 Proposed DevSecOps Team Structure

**Role & Permissions:**
- **Organization Role:** `maintain` (can manage organization settings, teams, and repositories)
- **Repository Permission:** `admin` on all repositories
- **Purpose:** Review and approve repository requests, manage infrastructure

**Justification:**
- `maintain` role allows team to manage repos without full org owner privileges
- Provides necessary access for DevOps operations while maintaining security
- Can approve workflows and manage team memberships

### 2.2 Update Root Module

**File:** `main.tf` (Add after repository module)

```hcl
# ============================================================================
# DevSecOps Team Management
# ============================================================================

# Load teams configuration
locals {
  teams_file = "${path.module}/data/teams.yaml"
  teams_data = fileexists(local.teams_file) ? yamldecode(file(local.teams_file)) : { teams = [] }

  # Normalize teams data
  all_teams = try(local.teams_data.teams, [])
}

# Create DevSecOps team
module "devsecops_team" {
  source = "./modules/github-teams"

  team_name    = "paloitmbb-devsecops"
  description  = "DevSecOps team with organization-level permissions to view and approve all repositories and pipelines"
  privacy      = "closed"

  # Grant admin access to all managed repositories
  repositories = [for repo in local.all_repositories : repo.name]
  permission   = "admin"
}

# Create repository-specific teams
module "repository_teams" {
  source   = "./modules/github-teams"
  for_each = { for team in local.all_teams : team.name => team }

  team_name    = each.value.name
  description  = each.value.description
  privacy      = try(each.value.privacy, "closed")
  repositories = [each.value.repository]
  permission   = each.value.permission

  depends_on = [module.github_repositories]
}
````

---

## Phase 3: Teams Data Structure

### 3.1 Create Teams YAML File

**File:** `data/teams.yaml`

```yaml
---
# GitHub Teams Configuration
# This file defines teams and their repository access permissions
# Teams are created via Terraform; membership is managed via GitHub API

teams:
  # Example: Teams for mbb-web-portal repository
  - name: mbb-web-portal-admin
    repository: mbb-web-portal
    permission: admin
    privacy: closed
    description: "Admin team for mbb-web-portal repository - full administrative access"

  - name: mbb-web-portal-dev
    repository: mbb-web-portal
    permission: push
    privacy: closed
    description: "Developer team for mbb-web-portal repository - write access for development"

  - name: mbb-web-portal-test
    repository: mbb-web-portal
    permission: push
    privacy: closed
    description: "Test team for mbb-web-portal repository - write access for testing activities"

  - name: mbb-web-portal-prod
    repository: mbb-web-portal
    permission: maintain
    privacy: closed
    description: "Production team for mbb-web-portal repository - maintain access for production releases"

  # Example: Teams for mbb-api-gateway repository
  - name: mbb-api-gateway-admin
    repository: mbb-api-gateway
    permission: admin
    privacy: closed
    description: "Admin team for mbb-api-gateway repository - full administrative access"

  - name: mbb-api-gateway-dev
    repository: mbb-api-gateway
    permission: push
    privacy: closed
    description: "Developer team for mbb-api-gateway repository - write access for development"

  - name: mbb-api-gateway-test
    repository: mbb-api-gateway
    permission: push
    privacy: closed
    description: "Test team for mbb-api-gateway repository - write access for testing activities"

  - name: mbb-api-gateway-prod
    repository: mbb-api-gateway
    permission: maintain
    privacy: closed
    description: "Production team for mbb-api-gateway repository - maintain access for production releases"

# Team Structure Convention:
# {repository-name}-{role}
#
# Roles:
# - admin: Full administrative access (admin permission)
# - dev: Developer access (push permission)
# - test: Test manager access (push permission)
# - prod: Production manager access (maintain permission)
#
# Note: Team membership is managed separately via GitHub API
# This file only defines team creation and repository permissions
```

### 3.2 Teams Data README

**File:** `data/TEAMS.md`

```markdown
# Teams Data Management

## Overview

The `teams.yaml` file defines GitHub teams and their repository access permissions. Teams are created and managed via Terraform, while team membership is managed through GitHub REST API calls in the automated workflow.

## Team Naming Convention

All teams follow this naming pattern:
```

{repository-name}-{role}

````

### Roles and Permissions

| Role | Suffix | Permission | Description |
|------|--------|------------|-------------|
| Admin | `-admin` | `admin` | Full administrative access including settings and team management |
| Developer | `-dev` | `push` | Write access for development activities |
| Test Manager | `-test` | `push` | Write access for testing activities |
| Production Manager | `-prod` | `maintain` | Maintain access for production releases and management |

## Automatic Team Creation

When a new repository is created via the automated workflow, the system automatically:

1. Creates 4 teams for the repository following the naming convention
2. Assigns appropriate permissions to each team
3. Populates the admin team with users specified in the repository request
4. Updates this YAML file with the new team definitions

## Manual Team Management

To manually add teams:

1. Edit `data/teams.yaml`
2. Add team definition following the structure:
   ```yaml
   - name: {repo-name}-{role}
     repository: {repo-name}
     permission: {admin|push|maintain}
     privacy: closed
     description: "{Role} team for {repo-name} repository"
````

3. Run Terraform: `./scripts/plan.sh dev` then `./scripts/apply.sh dev`

## Team Membership Management

Team memberships are **NOT** managed in this file or via Terraform. Use GitHub UI or API to:

- Add/remove team members
- Assign team maintainers
- Configure team settings

The automated workflow handles admin team membership population during repository creation.

````

---

## Phase 4: Update Issue Template

### 4.1 Enhanced Issue Template

**File:** `.github/ISSUE_TEMPLATE/new-repository.yml`

```yaml
name: New Repository Request
description: Request creation of a new GitHub repository with automated team setup
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

        **Note:** The repository will be created with 4 teams:
        - `{repo-name}-admin` - Full administrative access
        - `{repo-name}-dev` - Developer write access
        - `{repo-name}-test` - Test manager write access
        - `{repo-name}-prod` - Production manager maintain access

  - type: input
    id: repo-name
    attributes:
      label: Repository Name
      description: Name of the new repository (lowercase, hyphens only, no spaces)
      placeholder: "mbb-new-service"
    validations:
      required: true

  - type: textarea
    id: description
    attributes:
      label: Repository Description
      description: Brief description of the repository purpose and what it will contain
      placeholder: "This repository will contain..."
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

  - type: input
    id: admins
    attributes:
      label: Repository Admins
      description: Comma-separated GitHub usernames who will have admin access (will be validated)
      placeholder: "john-doe, jane-smith, bob-jones"
    validations:
      required: true

  - type: dropdown
    id: visibility
    attributes:
      label: Repository Visibility
      options:
        - private
        - internal
        - public
      default: 0
    validations:
      required: true

  - type: dropdown
    id: environment
    attributes:
      label: Target Environment
      description: Which environment should this repository be created in
      options:
        - dev
        - staging
        - production
      default: 0
    validations:
      required: true

  - type: checkboxes
    id: features
    attributes:
      label: Repository Features
      description: Select the features you want enabled
      options:
        - label: Enable Issues
          required: false
        - label: Enable Projects
          required: false
        - label: Enable Wiki
          required: false

  - type: checkboxes
    id: security
    attributes:
      label: Security Features
      description: Select security features (GHAS features require license)
      options:
        - label: Enable Vulnerability Alerts
          required: false
        - label: Enable Dependabot Alerts
          required: false
        - label: Enable Dependabot Security Updates
          required: false
        - label: Enable Advanced Security (GHAS)
          required: false
        - label: Enable Secret Scanning
          required: false
        - label: Enable Secret Scanning Push Protection
          required: false

  - type: input
    id: topics
    attributes:
      label: Repository Topics
      description: Comma-separated list of topics/tags for the repository
      placeholder: "backend, api, microservices, nodejs"

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

  - type: textarea
    id: branch-protection
    attributes:
      label: Branch Protection Requirements (Optional)
      description: Specify branch protection rules if different from defaults
      placeholder: |
        Required approving reviews: 2
        Require code owner reviews: yes
        Dismiss stale reviews: no
        Require signed commits: no

  - type: textarea
    id: additional-notes
    attributes:
      label: Additional Notes
      description: Any additional information or special requirements
      placeholder: "Please add any special configuration needs or notes here..."

  - type: checkboxes
    id: terms
    attributes:
      label: Acknowledgment
      description: Please confirm you understand the following
      options:
        - label: I understand that this repository will be created with 4 default teams
          required: true
        - label: I have listed all required admin users and verified their usernames
          required: true
        - label: I will manage additional team memberships after repository creation
          required: true
````

---

## Phase 5: Automated Workflow Implementation

### 5.1 GitHub Environment Setup

**Manual Step:** Create GitHub Environment for approval

1. Go to repository Settings → Environments
2. Create new environment: `repo-creation-approval`
3. Add required reviewers: `paloitmbb-devsecops` team
4. Set deployment branch pattern: `main`

### 5.2 Main Workflow File

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
      description: ${{ steps.parse.outputs.description }}
      tech-stack: ${{ steps.parse.outputs.tech-stack }}
      justification: ${{ steps.parse.outputs.justification }}
      admins: ${{ steps.parse.outputs.admins }}
      visibility: ${{ steps.parse.outputs.visibility }}
      environment: ${{ steps.parse.outputs.environment }}
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

            // Extract all fields
            const repoName = extractField(issueBody, 'Repository Name');
            const description = extractField(issueBody, 'Repository Description');
            const techStack = extractField(issueBody, 'Tech Stack');
            const techStackOther = extractField(issueBody, 'Other Tech Stack');
            const justification = extractField(issueBody, 'Business Justification');
            const admins = extractField(issueBody, 'Repository Admins');
            const visibility = extractField(issueBody, 'Repository Visibility');
            const environment = extractField(issueBody, 'Target Environment');
            const topics = extractField(issueBody, 'Repository Topics');
            const defaultBranch = extractField(issueBody, 'Default Branch Name');

            // Extract checkboxes
            const issuesEnabled = issueBody.includes('[x] Enable Issues');
            const projectsEnabled = issueBody.includes('[x] Enable Projects');
            const wikiEnabled = issueBody.includes('[x] Enable Wiki');

            // Security features
            const vulnAlerts = issueBody.includes('[x] Enable Vulnerability Alerts');
            const dependabotAlerts = issueBody.includes('[x] Enable Dependabot Alerts');
            const dependabotUpdates = issueBody.includes('[x] Enable Dependabot Security Updates');
            const advancedSecurity = issueBody.includes('[x] Enable Advanced Security');
            const secretScanning = issueBody.includes('[x] Enable Secret Scanning');
            const secretPushProtection = issueBody.includes('[x] Enable Secret Scanning Push Protection');

            // Determine final tech stack
            const finalTechStack = techStack === 'Others (specify below)' ? techStackOther : techStack;

            // Set outputs
            core.setOutput('repo-name', repoName);
            core.setOutput('description', description);
            core.setOutput('tech-stack', finalTechStack);
            core.setOutput('justification', justification);
            core.setOutput('admins', admins);
            core.setOutput('visibility', visibility);
            core.setOutput('environment', environment);
            core.setOutput('topics', topics);
            core.setOutput('default-branch', defaultBranch || 'main');
            core.setOutput('has-issues', issuesEnabled);
            core.setOutput('has-projects', projectsEnabled);
            core.setOutput('has-wiki', wikiEnabled);
            core.setOutput('enable-vuln-alerts', vulnAlerts);
            core.setOutput('enable-dependabot-alerts', dependabotAlerts);
            core.setOutput('enable-dependabot-updates', dependabotUpdates);
            core.setOutput('enable-advanced-security', advancedSecurity);
            core.setOutput('enable-secret-scanning', secretScanning);
            core.setOutput('enable-secret-push-protection', secretPushProtection);

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

      - name: Validate admin usernames
        id: validate-admins
        uses: actions/github-script@v7
        with:
          script: |
            const adminsString = '${{ steps.parse.outputs.admins }}';
            const adminList = adminsString.split(',').map(u => u.trim()).filter(u => u);

            if (adminList.length === 0) {
              core.setOutput('error', 'At least one admin user must be specified');
              core.setOutput('valid', 'false');
              return;
            }

            const invalidUsers = [];

            // Validate each username exists in organization
            for (const username of adminList) {
              try {
                await github.rest.users.getByUsername({ username });
              } catch (error) {
                invalidUsers.push(username);
              }
            }

            if (invalidUsers.length > 0) {
              core.setOutput('error', `Invalid usernames: ${invalidUsers.join(', ')}`);
              core.setOutput('valid', 'false');
              return;
            }

            core.setOutput('valid', 'true');
            core.setOutput('admin-list', JSON.stringify(adminList));

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

      - name: Consolidate validation
        id: validate
        run: |
          NAME_VALID="${{ steps.validate-name.outputs.valid }}"
          ADMINS_VALID="${{ steps.validate-admins.outputs.valid }}"
          REPO_EXISTS="${{ steps.check-repo.outputs.exists }}"

          if [[ "$NAME_VALID" == "true" && "$ADMINS_VALID" == "true" && "$REPO_EXISTS" != "true" ]]; then
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
            const adminsValid = '${{ steps.validate-admins.outputs.valid }}' === 'true';
            const repoExists = '${{ steps.check-repo.outputs.exists }}' === 'true';

            let commentBody = '## 🔍 Repository Request Validation\n\n';

            if (passed) {
              commentBody += '✅ **All validations passed!**\n\n';
              commentBody += '### Request Summary\n';
              commentBody += `- **Repository Name:** \`${{ steps.parse.outputs.repo-name }}\`\n`;
              commentBody += `- **Description:** ${{ steps.parse.outputs.description }}\n`;
              commentBody += `- **Tech Stack:** ${{ steps.parse.outputs.tech-stack }}\n`;
              commentBody += `- **Visibility:** ${{ steps.parse.outputs.visibility }}\n`;
              commentBody += `- **Environment:** ${{ steps.parse.outputs.environment }}\`\n`;
              commentBody += `- **Admins:** ${{ steps.parse.outputs.admins }}\n`;
              commentBody += `- **Default Branch:** ${{ steps.parse.outputs.default-branch }}\n\n`;
              
              commentBody += '### Teams to be Created\n';
              commentBody += `- \`${{ steps.parse.outputs.repo-name }}-admin\` (Admin permission)\n`;
              commentBody += `- \`${{ steps.parse.outputs.repo-name }}-dev\` (Write permission)\n`;
              commentBody += `- \`${{ steps.parse.outputs.repo-name }}-test\` (Write permission)\n`;
              commentBody += `- \`${{ steps.parse.outputs.repo-name }}-prod\` (Maintain permission)\n\n`;
              
              commentBody += '### Features Enabled\n';
              commentBody += `- Issues: ${{ steps.parse.outputs.has-issues }}\n`;
              commentBody += `- Projects: ${{ steps.parse.outputs.has-projects }}\n`;
              commentBody += `- Wiki: ${{ steps.parse.outputs.has-wiki }}\n\n`;
              
              commentBody += '### Security Features\n';
              commentBody += `- Vulnerability Alerts: ${{ steps.parse.outputs.enable-vuln-alerts }}\n`;
              commentBody += `- Dependabot Alerts: ${{ steps.parse.outputs.enable-dependabot-alerts }}\n`;
              commentBody += `- Dependabot Updates: ${{ steps.parse.outputs.enable-dependabot-updates }}\n`;
              commentBody += `- Advanced Security: ${{ steps.parse.outputs.enable-advanced-security }}\n\n`;
              
              commentBody += '---\n\n';
              commentBody += '⏳ **Awaiting approval from DevSecOps team...**\n';
              commentBody += 'Once approved, the repository and teams will be created automatically.';
            } else {
              commentBody += '❌ **Validation Failed**\n\n';
              commentBody += '### Errors Found:\n';
              
              if (!nameValid) {
                commentBody += `- ❌ Repository Name: ${{ steps.validate-name.outputs.error }}\n`;
              }
              if (!adminsValid) {
                commentBody += `- ❌ Admin Users: ${{ steps.validate-admins.outputs.error }}\n`;
              }
              if (repoExists) {
                commentBody += `- ❌ Repository Already Exists: ${{ steps.check-repo.outputs.error }}\n`;
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

  # ============================================================================
  # Job 2: Create Repository (Requires Approval)
  # ============================================================================
  create-repository:
    name: Create Repository and Teams
    runs-on: ubuntu-latest
    needs: validate-request
    if: needs.validate-request.outputs.validation-passed == 'true'
    environment: repo-creation-approval # Requires approval from paloitmbb-devsecops

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Configure Git
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"

      - name: Update repositories.yaml
        id: update-repos
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const yaml = require('js-yaml');

            // Read existing repositories.yaml
            const reposFile = 'data/repositories.yaml';
            const reposContent = fs.readFileSync(reposFile, 'utf8');
            const reposData = yaml.load(reposContent);

            // Parse topics
            const topicsString = '${{ needs.validate-request.outputs.topics }}';
            const topics = topicsString ? topicsString.split(',').map(t => t.trim()) : [];

            // Add tech stack to topics
            const techStack = '${{ needs.validate-request.outputs.tech-stack }}';
            if (techStack) {
              topics.push(techStack.toLowerCase().replace(/\s+/g, '-'));
            }

            // Create new repository entry
            const newRepo = {
              name: '${{ needs.validate-request.outputs.repo-name }}',
              description: '${{ needs.validate-request.outputs.description }}',
              visibility: '${{ needs.validate-request.outputs.visibility }}',
              features: {
                has_issues: ${{ needs.validate-request.outputs.has-issues }},
                has_projects: ${{ needs.validate-request.outputs.has-projects }},
                has_wiki: ${{ needs.validate-request.outputs.has-wiki }}
              },
              default_branch: '${{ needs.validate-request.outputs.default-branch }}',
              topics: topics,
              security: {
                enable_vulnerability_alerts: ${{ needs.validate-request.outputs.enable-vuln-alerts }},
                enable_advanced_security: ${{ needs.validate-request.outputs.enable-advanced-security }},
                enable_secret_scanning: ${{ needs.validate-request.outputs.enable-secret-scanning }},
                enable_secret_scanning_push_protection: ${{ needs.validate-request.outputs.enable-secret-push-protection }},
                enable_dependabot_alerts: ${{ needs.validate-request.outputs.enable-dependabot-alerts }},
                enable_dependabot_security_updates: ${{ needs.validate-request.outputs.enable-dependabot-updates }}
              }
            };

            // Add to repositories array
            reposData.repositories.push(newRepo);

            // Write back to file
            const updatedYaml = yaml.dump(reposData, { indent: 2, lineWidth: -1 });
            fs.writeFileSync(reposFile, updatedYaml, 'utf8');

            console.log('Successfully updated repositories.yaml');

      - name: Update teams.yaml
        id: update-teams
        run: |
          REPO_NAME="${{ needs.validate-request.outputs.repo-name }}"
          TEAMS_FILE="data/teams.yaml"

          # Create teams.yaml if it doesn't exist
          if [ ! -f "$TEAMS_FILE" ]; then
            cat > "$TEAMS_FILE" << 'EOF'
          ---
          # GitHub Teams Configuration
          teams: []
          EOF
          fi

          # Append 4 teams for the new repository
          cat >> "$TEAMS_FILE" << EOF

            - name: ${REPO_NAME}-admin
              repository: ${REPO_NAME}
              permission: admin
              privacy: closed
              description: "Admin team for ${REPO_NAME} repository - full administrative access"
            
            - name: ${REPO_NAME}-dev
              repository: ${REPO_NAME}
              permission: push
              privacy: closed
              description: "Developer team for ${REPO_NAME} repository - write access for development"
            
            - name: ${REPO_NAME}-test
              repository: ${REPO_NAME}
              permission: push
              privacy: closed
              description: "Test team for ${REPO_NAME} repository - write access for testing activities"
            
            - name: ${REPO_NAME}-prod
              repository: ${REPO_NAME}
              permission: maintain
              privacy: closed
              description: "Production team for ${REPO_NAME} repository - maintain access for production releases"
          EOF

          echo "Successfully updated teams.yaml"

      - name: Commit changes to main
        run: |
          git add data/repositories.yaml data/teams.yaml
          git commit -m "feat: ✨ add repository ${{ needs.validate-request.outputs.repo-name }} and associated teams

          Repository request from issue #${{ github.event.issue.number }}

          - Repository: ${{ needs.validate-request.outputs.repo-name }}
          - Tech Stack: ${{ needs.validate-request.outputs.tech-stack }}
          - Environment: ${{ needs.validate-request.outputs.environment }}
          - Created 4 teams: admin, dev, test, prod

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
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Terraform Apply
        id: terraform-apply
        run: |
          ./scripts/apply.sh ${{ needs.validate-request.outputs.environment }} -auto-approve
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Populate Admin Team Membership
        id: populate-admins
        uses: actions/github-script@v7
        with:
          script: |
            const adminsString = '${{ needs.validate-request.outputs.admins }}';
            const adminList = adminsString.split(',').map(u => u.trim()).filter(u => u);
            const teamSlug = '${{ needs.validate-request.outputs.repo-name }}-admin';

            const results = [];

            for (const username of adminList) {
              try {
                await github.rest.teams.addOrUpdateMembershipForUserInOrg({
                  org: context.repo.owner,
                  team_slug: teamSlug,
                  username: username,
                  role: 'member'
                });
                results.push(`✅ Added ${username} to ${teamSlug}`);
              } catch (error) {
                results.push(`❌ Failed to add ${username}: ${error.message}`);
              }
            }

            core.setOutput('results', results.join('\n'));
            return results;

      - name: Post success comment
        if: success()
        uses: actions/github-script@v7
        with:
          script: |
            const repoName = '${{ needs.validate-request.outputs.repo-name }}';
            const org = context.repo.owner;

            const commentBody = `## ✅ Repository Created Successfully!

            Your repository has been created and configured.

            ### 🎉 Repository Details
            - **Repository:** [${org}/${repoName}](https://github.com/${org}/${repoName})
            - **Visibility:** ${{ needs.validate-request.outputs.visibility }}
            - **Default Branch:** ${{ needs.validate-request.outputs.default-branch }}
            - **Environment:** ${{ needs.validate-request.outputs.environment }}

            ### 👥 Teams Created
            - [\`${repoName}-admin\`](https://github.com/orgs/${org}/teams/${repoName}-admin) - Admin access
            - [\`${repoName}-dev\`](https://github.com/orgs/${org}/teams/${repoName}-dev) - Write access
            - [\`${repoName}-test\`](https://github.com/orgs/${org}/teams/${repoName}-test) - Write access
            - [\`${repoName}-prod\`](https://github.com/orgs/${org}/teams/${repoName}-prod) - Maintain access

            ### 👤 Admin Team Members
            ${{ steps.populate-admins.outputs.results }}

            ### 📋 Next Steps
            1. Visit your repository: https://github.com/${org}/${repoName}
            2. Add team members to dev, test, and prod teams via GitHub UI
            3. Configure branch protection rules if needed
            4. Start developing! 🚀

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

## Phase 6: Implementation Checklist

### 6.1 Pre-Implementation Tasks

- [ ] Review and approve implementation plan
- [ ] Ensure GitHub token has required permissions (`repo`, `admin:org`, `workflow`)
- [ ] Verify Terraform backend is properly configured
- [ ] Backup existing data files (`repositories.yaml`)

### 6.2 Module Creation

- [ ] Create `modules/github-teams/` directory structure
- [ ] Implement `main.tf` for teams module
- [ ] Implement `variables.tf` with validation rules
- [ ] Implement `outputs.tf` with team details
- [ ] Create `versions.tf` matching project requirements
- [ ] Write comprehensive README.md with usage examples
- [ ] Test module independently with sample team

### 6.3 Data Structure Setup

- [ ] Create `data/teams.yaml` with structure
- [ ] Create `data/TEAMS.md` documentation
- [ ] Migrate existing repository teams (if any) to YAML format
- [ ] Validate YAML syntax

### 6.4 Root Module Updates

- [ ] Update `main.tf` with teams module integration
- [ ] Add DevSecOps team module instantiation
- [ ] Add repository teams module instantiation
- [ ] Update `outputs.tf` to include team information
- [ ] Test with `terraform plan` in dev environment

### 6.5 Issue Template Enhancement

- [ ] Update `.github/ISSUE_TEMPLATE/new-repository.yml`
- [ ] Add tech stack dropdown with options
- [ ] Add "Others" tech stack input field
- [ ] Add justification textarea
- [ ] Add admins input field with validation description
- [ ] Add acknowledgment checkboxes
- [ ] Test issue template creation

### 6.6 GitHub Environment Setup

- [ ] Create `repo-creation-approval` environment in GitHub settings
- [ ] Add `paloitmbb-devsecops` team as required reviewers
- [ ] Configure deployment branch restrictions to `main`
- [ ] Test approval workflow

### 6.7 Workflow Implementation

- [ ] Update `.github/workflows/repo-request.yml`
- [ ] Implement validation job with all checks
- [ ] Implement create-repository job with approval requirement
- [ ] Add YAML file update logic
- [ ] Add Terraform apply integration
- [ ] Add GitHub API team membership population
- [ ] Add comprehensive comment notifications
- [ ] Test workflow with sample issue

### 6.8 Testing Plan

- [ ] **Test 1:** Create test issue with valid data
- [ ] **Test 2:** Verify validation passes and comment posted
- [ ] **Test 3:** Approve workflow and verify execution
- [ ] **Test 4:** Verify repository created with correct settings
- [ ] **Test 5:** Verify 4 teams created with correct permissions
- [ ] **Test 6:** Verify admin team populated with correct members
- [ ] **Test 7:** Test invalid repository name (validation failure)
- [ ] **Test 8:** Test invalid admin username (validation failure)
- [ ] **Test 9:** Test duplicate repository name (validation failure)
- [ ] **Test 10:** End-to-end test in dev environment

### 6.9 Documentation

- [ ] Update main README.md with workflow documentation
- [ ] Create runbook for troubleshooting common issues
- [ ] Document team management procedures
- [ ] Update project structure documentation
- [ ] Create user guide for repository requesters

### 6.10 Deployment

- [ ] Deploy to dev environment
- [ ] Run full test suite in dev
- [ ] Deploy to staging environment
- [ ] Run smoke tests in staging
- [ ] Deploy to production environment
- [ ] Monitor first few production requests

---

## Phase 7: Rollout Plan

### 7.1 Development Environment (Week 1)

1. **Day 1-2:** Implement Terraform modules and data structures
2. **Day 3-4:** Update root module and test locally
3. **Day 5:** Deploy to dev environment and run Terraform apply

### 7.2 Workflow Development (Week 2)

1. **Day 1-2:** Update issue template and create GitHub environment
2. **Day 3-4:** Implement workflow YAML with validation logic
3. **Day 5:** Implement creation and notification logic

### 7.3 Testing Phase (Week 3)

1. **Day 1-2:** Execute test plan in dev environment
2. **Day 3:** Fix identified issues
3. **Day 4-5:** Regression testing and documentation

### 7.4 Staging Deployment (Week 4)

1. **Day 1:** Deploy to staging environment
2. **Day 2-3:** Run full test suite in staging
3. **Day 4-5:** User acceptance testing with DevSecOps team

### 7.5 Production Deployment (Week 5)

1. **Day 1:** Production deployment during maintenance window
2. **Day 2-3:** Monitor first production requests
3. **Day 4-5:** Gather feedback and create iteration backlog

---

## Phase 8: Success Criteria

### 8.1 Functional Requirements

- ✅ Users can create repository requests via GitHub issues
- ✅ Workflow validates all input fields automatically
- ✅ DevSecOps team receives approval requests
- ✅ Repositories are created with correct configuration
- ✅ 4 teams are created automatically per repository
- ✅ Admin team is populated with specified users
- ✅ Success/failure notifications posted to issue
- ✅ YAML data files updated automatically

### 8.2 Non-Functional Requirements

- ✅ Workflow completes within 5 minutes (excluding approval wait time)
- ✅ All operations are idempotent (can be retried safely)
- ✅ Comprehensive error handling and logging
- ✅ Zero manual intervention required after approval
- ✅ Audit trail maintained in Git history
- ✅ Documentation comprehensive and up-to-date

### 8.3 Security Requirements

- ✅ GitHub token permissions follow least privilege principle
- ✅ Approval required from authorized team members only
- ✅ Input validation prevents injection attacks
- ✅ Team memberships validated against org members
- ✅ All operations logged and auditable

---

## Phase 9: Monitoring and Maintenance

### 9.1 Monitoring

- Monitor workflow success/failure rates via GitHub Actions insights
- Track average time from request to completion
- Monitor Terraform apply success rates
- Alert on consecutive workflow failures

### 9.2 Maintenance Tasks

- **Weekly:** Review failed workflow runs and resolve issues
- **Monthly:** Review and update tech stack options based on usage
- **Quarterly:** Audit team permissions and memberships
- **Annually:** Review and optimize workflow performance

---

## Phase 10: Troubleshooting Guide

### 10.1 Common Issues

| Issue                               | Possible Cause           | Resolution                            |
| ----------------------------------- | ------------------------ | ------------------------------------- |
| Validation fails for valid username | User not in organization | Add user to org or use org member     |
| Terraform apply fails               | State lock conflict      | Wait for lock release or force unlock |
| Team creation fails                 | Team already exists      | Check teams.yaml for duplicates       |
| Admin population fails              | Invalid team slug        | Verify team was created by Terraform  |
| Workflow stuck on approval          | No reviewers available   | Ensure DevSecOps team has members     |

### 10.2 Rollback Procedures

If workflow fails after repository creation:

1. **Manual cleanup:**

   ```bash
   # Delete repository
   gh repo delete org/repo-name --yes

   # Delete teams
   gh api -X DELETE /orgs/org/teams/repo-name-admin
   gh api -X DELETE /orgs/org/teams/repo-name-dev
   gh api -X DELETE /orgs/org/teams/repo-name-test
   gh api -X DELETE /orgs/org/teams/repo-name-prod
   ```

2. **Revert YAML changes:**

   ```bash
   git revert HEAD
   git push origin main
   ```

3. **Remove from Terraform state:**
   ```bash
   terraform state rm 'module.github_repositories["repo-name"]'
   terraform state rm 'module.repository_teams["repo-name-admin"]'
   # ... repeat for all teams
   ```

---

## Appendices

### Appendix A: Required GitHub Permissions

```yaml
Token Scopes:
  - repo (Full control of private repositories)
  - admin:org (Full control of organizations)
  - workflow (Update GitHub Action workflows)
  - read:org (Read org and team membership)
```

### Appendix B: Example Workflow Run

```
Issue Created: #123 "[REPO REQUEST] mbb-payment-service"
    ↓
Validation Job (30 seconds)
    ✅ Repository name valid
    ✅ Admin users validated
    ✅ Repository doesn't exist
    📝 Posted summary comment
    ↓
Awaiting Approval (manual step)
    ⏳ DevSecOps team reviews request
    ✅ Team member approves
    ↓
Creation Job (3 minutes)
    ✅ Updated repositories.yaml
    ✅ Updated teams.yaml
    ✅ Committed to main branch
    ✅ Terraform init completed
    ✅ Terraform apply completed
    ✅ Repository created
    ✅ 4 teams created
    ✅ Admin team populated
    📝 Posted success comment
    ✅ Closed issue
    ↓
Complete! Repository Ready 🎉
```

### Appendix C: File Change Summary

**New Files:**

- `modules/github-teams/main.tf`
- `modules/github-teams/variables.tf`
- `modules/github-teams/outputs.tf`
- `modules/github-teams/versions.tf`
- `modules/github-teams/README.md`
- `data/teams.yaml`
- `data/TEAMS.md`

**Modified Files:**

- `main.tf` (add teams module integration)
- `outputs.tf` (add team outputs)
- `.github/ISSUE_TEMPLATE/new-repository.yml` (enhance with new fields)
- `.github/workflows/repo-request.yml` (complete workflow implementation)

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
