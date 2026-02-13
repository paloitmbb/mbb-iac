# Preparation Plan & Execution Plan

> **Project:** Maybank GitHub Enterprise Automation
> **Version:** 1.0
> **Last Updated:** 10 February 2026

---

## Part 1: Preparation Plan

### 1.1 Prerequisites

| # | Prerequisite | Owner | Status |
|---|-------------|-------|--------|
| 1 | GitHub Enterprise Cloud organization(s) with API access | Platform Team | ✅ Done |
| 2 | GitHub App or PAT with `admin:org`, `repo`, `manage_copilot` scopes | Platform Team | 🔲 Pending |
| 3 | Terraform >= 1.14.0 installed | DevOps | ✅ Done |
| 4 | Terraform state backend (S3 + DynamoDB or equivalent) | DevOps | 🔲 Pending |
| 5 | GitHub Actions enabled on the automation repo | Platform Team | ✅ Done |
| 6 | CODEOWNERS configured for PR approval routing | DevOps | ✅ Done |
| 7 | Team members with required GitHub roles (org owner / admin) | Platform Team | 🔲 Pending |

### 1.2 Terraform Provider Requirements

```hcl
terraform {
  required_version = ">= 1.14.0"

  required_providers {
    github = {
      source  = "integrations/github"
      version = ">= 6.10"
    }
  }
}
```

### 1.3 GitHub API Scopes Required

| Module | Required Scopes |
|--------|----------------|
| github-repo | `repo`, `admin:org` |
| github-team | `admin:org`, `read:org` |
| github-copilot | `manage_billing:copilot`, `admin:org` |
| github-org-settings | `admin:org` |
| github-repo-settings | `repo`, `admin:repo_hook` |

### 1.4 Repository Secrets to Configure

| Secret Name | Description | Used By |
|-------------|------------|---------|
| `GH_TERRAFORM_TOKEN` | PAT/App token for Terraform provider | All workflows |
| `TF_STATE_BUCKET` | State backend bucket name | All workflows |
| `TF_STATE_REGION` | State backend region | All workflows |
| `TF_STATE_LOCK_TABLE` | DynamoDB table for state locking | All workflows |

### 1.5 Naming Conventions

| Resource | Pattern | Example |
|----------|---------|---------|
| Repository | `<org-prefix>-<project>-<component>` | `maybank-digital-frontend` |
| Team | `<org-prefix>-<department>-<role>` | `maybank-platform-admins` |
| Environment branch | `env/<environment>` | `env/production` |
| Issue labels | `<type>-request` | `new-repo-request` |

---

## Part 2: Task Breakdown

### Phase 1 — Repository Automation (Current)

| Task | Description | Priority | Status |
|------|------------|----------|--------|
| 1.1 | Define `github-repo` module with all resource types | High | ✅ Done |
| 1.2 | Set up 3 environments (SIT, Staging, Prod) | High | ✅ Done |
| 1.3 | Hardcode enforced defaults (security, archive, branch) | High | ✅ Done |
| 1.4 | Create `data/repositories.yaml` schema | High | 🔲 To Do |
| 1.5 | Add YAML-to-Terraform data loader in modules | High | 🔲 To Do |
| 1.6 | Create issue template: `new-repo-request.yml` | High | 🔲 To Do |
| 1.7 | Build `issue-new-repo.yml` workflow | High | 🔲 To Do |
| 1.8 | Build PR validation workflow (YAML lint + plan) | Medium | ✅ Partial |
| 1.9 | Build deploy workflows per environment | Medium | ✅ Done |
| 1.10 | Test end-to-end: issue → PR → merge → apply | High | 🔲 To Do |

### Phase 2 — Team & Membership Management

| Task | Description | Priority | Status |
|------|------------|----------|--------|
| 2.1 | Create `modules/github-team/` module | High | 🔲 To Do |
| 2.2 | Define `data/teams.yaml` schema | High | 🔲 To Do |
| 2.3 | Create issue template: `team-member-request.yml` | Medium | 🔲 To Do |
| 2.4 | Build `issue-team-member.yml` workflow | Medium | 🔲 To Do |
| 2.5 | Wire module into environment `main.tf` | High | 🔲 To Do |
| 2.6 | Test add/remove user flows | High | 🔲 To Do |

### Phase 3 — GitHub Copilot License Management

| Task | Description | Priority | Status |
|------|------------|----------|--------|
| 3.1 | Create `modules/github-copilot/` module | High | 🔲 To Do |
| 3.2 | Define `data/copilot-licenses.yaml` schema | High | 🔲 To Do |
| 3.3 | Create issue template: `copilot-license-request.yml` | Medium | 🔲 To Do |
| 3.4 | Build `issue-copilot-license.yml` workflow | Medium | 🔲 To Do |
| 3.5 | Wire module into environment `main.tf` | High | 🔲 To Do |
| 3.6 | Test assign/revoke flows | High | 🔲 To Do |

### Phase 4 — Organization & Repository Settings

| Task | Description | Priority | Status |
|------|------------|----------|--------|
| 4.1 | Create `modules/github-org-settings/` module | Medium | 🔲 To Do |
| 4.2 | Create `modules/github-repo-settings/` module | Medium | 🔲 To Do |
| 4.3 | Define `data/org-settings.yaml` schema | Medium | 🔲 To Do |
| 4.4 | Wire modules into environment `main.tf` | Medium | 🔲 To Do |
| 4.5 | Test org & repo settings changes | Medium | 🔲 To Do |

---

## Part 3: Execution Plan

### 3.1 Phase 1 Execution — Repository Automation

#### Step 1: Create YAML Data Schema

Create `data/repositories.yaml` as the source of truth:

```yaml
# data/repositories.yaml
repositories:
  maybank-digital-frontend:
    organization: maybank-sandbox
    description: "Frontend application for Maybank digital banking"
    visibility: private
    topics:
      - frontend
      - react
      - production
    has_issues: true
    has_projects: true
    enable_branch_protection: true
    required_approving_review_count: 2
    vulnerability_alerts: true
    allow_merge_commit: false
    allow_squash_merge: true
    allow_rebase_merge: false
    enable_ruleset: true
    ruleset_name: "production-protection"
    team_permissions:
      platform-admins: "admin"
      frontend-devs: "push"
```

#### Step 2: Create Issue Template

Create `.github/ISSUE_TEMPLATE/new-repo-request.yml`:

```yaml
name: "New Repository Request"
description: "Request creation of a new GitHub repository in any accessible organization"
title: "[New Repo] "
labels: ["new-repo-request"]
body:
  - type: input
    id: organization
    attributes:
      label: "Organization"
      description: "The GitHub organization where the repository will be created"
      placeholder: "maybank-sandbox"
    validations:
      required: true

  - type: input
    id: repo_name
    attributes:
      label: "Repository Name"
      description: "Must follow naming convention: <org-prefix>-<project>-<component>"
      placeholder: "maybank-digital-frontend"
    validations:
      required: true

  - type: dropdown
    id: visibility
    attributes:
      label: "Visibility"
      options:
        - private
        - internal
        - public
    validations:
      required: true

  - type: textarea
    id: description
    attributes:
      label: "Repository Description"
      placeholder: "Brief description of the repository purpose"
    validations:
      required: true

  - type: input
    id: topics
    attributes:
      label: "Topics (comma-separated)"
      placeholder: "frontend, react, production"

  - type: dropdown
    id: environment
    attributes:
      label: "Target Environment"
      options:
        - sit
        - staging
        - production
        - all
    validations:
      required: true

  - type: checkboxes
    id: features
    attributes:
      label: "Repository Features"
      options:
        - label: "Enable Issues"
          required: false
        - label: "Enable Projects"
          required: false
        - label: "Enable Branch Protection"
          required: false
        - label: "Enable Repository Ruleset"
          required: false

  - type: dropdown
    id: merge_strategy
    attributes:
      label: "Merge Strategy"
      options:
        - squash-only
        - merge-only
        - rebase-only
        - all
    validations:
      required: true

  - type: input
    id: approvers_count
    attributes:
      label: "Required Approving Reviews"
      placeholder: "2"
```

#### Step 3: Build Issue Handler Workflow

```yaml
# .github/workflows/issue-new-repo.yml
name: "Handle New Repo Request"

on:
  issues:
    types: [opened]

jobs:
  validate-and-create-pr:
    if: contains(github.event.issue.labels.*.name, 'new-repo-request')
    runs-on: ubuntu-latest
    permissions:
      issues: write
      contents: write
      pull-requests: write

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Parse Issue Form
        id: parse
        uses: stefanbuck/github-issue-parser@v3
        with:
          template-path: .github/ISSUE_TEMPLATE/new-repo-request.yml

      - name: Validate Organization Exists
        id: validate_org
        run: |
          ORG="${{ steps.parse.outputs.issueparser_organization }}"
          HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "Authorization: Bearer ${{ secrets.GH_ADMIN_TOKEN }}" \
            "https://api.github.com/orgs/${ORG}")
          if [[ "$HTTP_STATUS" != "200" ]]; then
            echo "valid=false" >> $GITHUB_OUTPUT
            echo "error=Organization '${ORG}' does not exist or is not accessible" >> $GITHUB_OUTPUT
          else
            echo "valid=true" >> $GITHUB_OUTPUT
            # Extract org prefix for naming validation
            ORG_PREFIX=$(echo "$ORG" | sed 's/-sandbox$//' | sed 's/-enterprise$//')
            echo "org_prefix=${ORG_PREFIX}" >> $GITHUB_OUTPUT
          fi

      - name: Validate Naming Convention
        if: steps.validate_org.outputs.valid == 'true'
        id: validate
        run: |
          REPO_NAME="${{ steps.parse.outputs.issueparser_repo_name }}"
          ORG_PREFIX="${{ steps.validate_org.outputs.org_prefix }}"

          # Check naming convention: must start with org prefix
          if [[ ! "$REPO_NAME" =~ ^${ORG_PREFIX}-[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
            echo "valid=false" >> $GITHUB_OUTPUT
            echo "error=Repository name must follow pattern: ${ORG_PREFIX}-<project>-<component>" >> $GITHUB_OUTPUT
          else
            echo "valid=true" >> $GITHUB_OUTPUT
          fi

      - name: Comment Validation Failure
        if: steps.validate.outputs.valid == 'false'
        uses: peter-evans/create-or-update-comment@v4
        with:
          issue-number: ${{ github.event.issue.number }}
          body: |
            ❌ **Validation Failed**

            ${{ steps.validate.outputs.error }}

            Please close this issue, fix the name, and submit a new request.

      - name: Label as Invalid
        if: steps.validate.outputs.valid == 'false'
        run: gh issue edit ${{ github.event.issue.number }} --add-label "invalid"
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Update repositories.yaml
        if: steps.validate.outputs.valid == 'true'
        run: |
          # Parse values from issue form
          REPO_NAME="${{ steps.parse.outputs.issueparser_repo_name }}"
          DESCRIPTION="${{ steps.parse.outputs.issueparser_description }}"
          VISIBILITY="${{ steps.parse.outputs.issueparser_visibility }}"
          TOPICS="${{ steps.parse.outputs.issueparser_topics }}"

          ORG="${{ steps.parse.outputs.issueparser_organization }}"

          # Append new repo config to data/repositories.yaml
          python3 scripts/add_repo_to_yaml.py \
            --name "$REPO_NAME" \
            --org "$ORG" \
            --description "$DESCRIPTION" \
            --visibility "$VISIBILITY" \
            --topics "$TOPICS"

      - name: Create Pull Request
        if: steps.validate.outputs.valid == 'true'
        uses: peter-evans/create-pull-request@v6
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          commit-message: "feat: add repository ${{ steps.parse.outputs.issueparser_repo_name }}"
          title: "feat: New repo request - ${{ steps.parse.outputs.issueparser_repo_name }}"
          body: |
            ## New Repository Request

            Closes #${{ github.event.issue.number }}

            **Organization:** `${{ steps.parse.outputs.issueparser_organization }}`
            **Repository:** `${{ steps.parse.outputs.issueparser_repo_name }}`
            **Visibility:** ${{ steps.parse.outputs.issueparser_visibility }}
            **Description:** ${{ steps.parse.outputs.issueparser_description }}

            ---
            This PR was auto-generated from issue #${{ github.event.issue.number }}.
            Terraform plan will run automatically. Review and approve to proceed.
          branch: "repo-request/${{ steps.parse.outputs.issueparser_repo_name }}"
          labels: "terraform,auto-generated"

      - name: Comment PR Link
        if: steps.validate.outputs.valid == 'true'
        uses: peter-evans/create-or-update-comment@v4
        with:
          issue-number: ${{ github.event.issue.number }}
          body: |
            ✅ **Validation Passed**

            A Pull Request has been created with your repository configuration.
            Terraform plan will run automatically on the PR.

            Once reviewed and merged, the repository will be created.
```

#### Step 4: PR Validation Workflow (Enhancement)

```yaml
# Additions to repo-validation-terraform.yml
- name: Validate YAML
  run: |
    python3 -c "
    import yaml, sys
    with open('data/repositories.yaml') as f:
      data = yaml.safe_load(f)
    if not data or 'repositories' not in data:
      print('ERROR: Invalid repositories.yaml structure')
      sys.exit(1)
    print(f'Valid: {len(data[\"repositories\"])} repositories defined')
    "

- name: Terraform Plan
  run: |
    cd environments/${{ matrix.environment }}
    terraform init
    terraform plan -var-file=terraform.tfvars -no-color
```

#### Step 5: Post-Merge Apply & Issue Closure

```yaml
# In terraform-prod.yml (on merge to main)
- name: Terraform Apply
  run: |
    cd environments/prod
    terraform apply -var-file=terraform.tfvars -auto-approve

- name: Close Related Issue
  if: success()
  run: |
    # Extract issue number from PR body
    ISSUE_NUM=$(echo "${{ github.event.pull_request.body }}" | grep -oP 'Closes #\K\d+')
    if [ -n "$ISSUE_NUM" ]; then
      gh issue close "$ISSUE_NUM" \
        --comment "✅ Repository has been successfully created! Terraform apply completed."
    fi
  env:
    GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

### 3.2 Phase 2 Execution — Team Management

#### Step 1: Create Module

```hcl
# modules/github-team/main.tf
resource "github_team" "this" {
  for_each = var.teams

  name        = each.key
  description = each.value.description
  privacy     = each.value.privacy
  parent_team_id = each.value.parent_team_id
}

resource "github_team_membership" "members" {
  for_each = {
    for item in local.team_memberships :
    "${item.team}-${item.username}" => item
  }

  team_id  = github_team.this[each.value.team].id
  username = each.value.username
  role     = each.value.role
}
```

#### Step 2: Define Data Schema

```yaml
# data/teams.yaml
teams:
  maybank-platform-admins:
    description: "Platform engineering admin team"
    privacy: closed
    members:
      - username: user1
        role: maintainer
      - username: user2
        role: member
    repositories:
      maybank-digital-frontend: admin
      maybank-digital-backend: admin
```

#### Step 3: Wire into Environment

```hcl
# environments/<env>/main.tf
module "github_teams" {
  source = "../../modules/github-team"
  teams  = yamldecode(file("../../data/teams.yaml"))["teams"]
}
```

---

### 3.3 Phase 3 Execution — Copilot License Management

#### Step 1: Create Module

```hcl
# modules/github-copilot/main.tf
# Note: As of 2026, use the github_copilot_organization_settings
# and API-based seat management

resource "github_copilot_organization_settings" "this" {
  seat_management_setting = var.seat_management_setting
  cli                     = var.copilot_cli
  ide_chat                = var.copilot_ide_chat
}

# Seat assignments via null_resource + GitHub API
# (until native Terraform resource is available)
resource "null_resource" "copilot_seats" {
  for_each = var.copilot_seats

  provisioner "local-exec" {
    command = <<-EOT
      curl -X POST \
        -H "Authorization: Bearer ${var.github_token}" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/orgs/${var.organization}/copilot/billing/selected_users" \
        -d '{"selected_usernames":["${each.value.username}"]}'
    EOT
  }
}
```

#### Step 2: Define Data Schema

```yaml
# data/copilot-licenses.yaml
copilot:
  seat_management: assign_selected
  assigned_users:
    - username: developer1
      team: frontend-devs
    - username: developer2
      team: backend-devs
  denied_users: []
```

---

### 3.4 Deployment Order

```
Phase 1 (Repos)  ──▶  Phase 2 (Teams)  ──▶  Phase 3 (Copilot)  ──▶  Phase 4 (Settings)
     │                      │                      │                       │
     ▼                      ▼                      ▼                       ▼
  SIT ──▶ STG ──▶ PROD   SIT ──▶ STG ──▶ PROD   SIT ──▶ STG ──▶ PROD   SIT ──▶ STG ──▶ PROD
```

---

## Part 4: End-to-End Workflow Summary

### Complete Flow: New Repository Request

```
Step  Action                                          Actor            Automation
────  ──────────────────────────────────────────  ───────────────  ──────────
 1    Create issue - select org + fill repo details    Developer        Manual
 2    Validate org exists via GitHub API               —                GitHub Actions
 3    Validate naming convention (<org-prefix>-name)   —                GitHub Actions
 4    Check repo doesn't already exist                 —                GitHub Actions
 5    Parse issue template fields                      —                GitHub Actions
 6    Generate YAML config with org field              —                GitHub Actions
 7    Create PR with data/repositories.yaml            —                GitHub Actions
 8    YAML validation runs on PR                       —                GitHub Actions
 9    Terraform plan runs on PR                        —                GitHub Actions
10    Team reviews and approves PR                     Platform Team    Manual
11    PR merged to main                                Platform Team    Manual
12    Terraform apply (SIT → Staging → Production)     —                GitHub Actions
13    Issue closed with success notification            —                GitHub Actions
```

---

## Part 5: Risk Mitigation

| Risk | Mitigation |
|------|-----------|
| Accidental repo deletion | `archive_on_destroy = true` enforced in module |
| Misconfigured security | Security scanning hardcoded as `enabled` |
| State file corruption | Remote backend with locking + encryption |
| Unauthorized changes | PR-based workflow, CODEOWNERS approval required |
| Token leakage | Secrets stored in GitHub Actions, never in code |
| Naming conflicts | Automated naming convention validation (org prefix + uniqueness check) |
| Terraform drift | Periodic `terraform plan` checks via scheduled workflows |

---

## Part 6: Success Criteria

| Criteria | Measurement |
|----------|-------------|
| End-to-end repo creation via issue | Issue → PR → Merge → Repo exists in < 15 min |
| Zero manual Terraform commands | All apply/plan via GitHub Actions |
| All repos have security scanning | `security_and_analysis` block present on all repos |
| All repos archived on destroy | `archive_on_destroy = true` on all repos |
| Audit trail for all changes | Every change has a linked issue + PR |
| Multi-environment deployment | Same change applied to SIT → Staging → Prod |
