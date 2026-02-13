# Architecture Document — GitHub Resource Automation with Terraform

> **Project:** Maybank GitHub Enterprise Automation
> **Version:** 1.1
> **Last Updated:** 11 February 2026

---

## 1. Overview

This project automates the provisioning and management of GitHub Enterprise resources using Terraform. It follows an Infrastructure-as-Code (IaC) approach where all GitHub configurations — repositories, teams, org settings, Copilot licenses, and more — are declared in Terraform and applied through CI/CD pipelines.

### 1.1 Scope

| # | Capability | Status |
|---|-----------|--------|
| 1 | Repository creation & configuration (any org) | ✅ In Progress |
| 2 | Add/remove users to teams | 🔜 Planned |
| 3 | GitHub Copilot license assignment | 🔜 Planned |
| 4 | Repository settings management | ✅ In Progress |
| 5 | Organization settings management | 🔜 Planned |
| 6 | **GHES → GHEC repository migration** | 🔜 Planned |
| 7 | Repository archival management | ✅ In Progress |
| 8 | CODEOWNERS automation | ✅ In Progress |

> Additional capabilities will be added in future iterations.

---

## 2. High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        GitHub Enterprise Cloud                         │
│                                                                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐ │
│  │  Repos   │  │  Teams   │  │ Copilot  │  │ Org      │  │ Branch  │ │
│  │          │  │  & Users │  │ Licenses │  │ Settings │  │ Protect │ │
│  └────▲─────┘  └────▲─────┘  └────▲─────┘  └────▲─────┘  └────▲────┘ │
│       │              │             │              │             │      │
└───────┼──────────────┼─────────────┼──────────────┼─────────────┼──────┘
        │              │             │              │             │
        └──────────────┴──────┬──────┴──────────────┴─────────────┘
                              │
┌─────────────────────────────┼──────────────────────────────────────────┐
│     GHES (Source)           │                                          │
│  ┌──────────┐  ┌──────────┐ │                                          │
│  │  Repos   │  │  Metadata│ │  ════════════════════════╗               │
│  │  (git)   │  │  (API)   │─┘  Migration Pipeline      ║               │
│  └──────────┘  └──────────┘    (gh gei / API-based)    ║               │
│                                ════════════════════════╝               │
└───────────────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────▼──────────┐
                    │  GitHub Provider   │
                    │  (Terraform)       │
                    └─────────▲──────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
     ┌────────▼──────┐ ┌─────▼──────┐ ┌──────▼───────┐
     │  Dev (SIT)    │ │  Staging   │ │  Production  │
     │  Environment  │ │ Environment│ │  Environment │
     └────────▲──────┘ └─────▲──────┘ └──────▲───────┘
              │               │               │
              └───────────────┼───────────────┘
                              │
                    ┌─────────▼──────────┐
                    │  GitHub Actions    │
                    │  CI/CD Pipelines   │
                    └─────────▲──────────┘
                              │
                    ┌─────────▼──────────┐
                    │  Issue Templates   │
                    │  & Pull Requests   │
                    └────────────────────┘
```

---

## 3. Project Structure (Modular Terraform)

```
mbb-github/
├── .github/
│   ├── CODEOWNERS
│   ├── ISSUE_TEMPLATE/
│   │   ├── new-repo-request.yml           # Issue form for new repo (includes org selection)
│   │   ├── team-member-request.yml        # Issue form for team changes
│   │   ├── copilot-license-request.yml    # Issue form for Copilot license
│   │   ├── archive-repo-request.yml       # Issue form for repo archival
│   │   └── ghes-migration-request.yml     # Issue form for GHES → GHEC migration
│   └── workflows/
│       ├── repo-validation-terraform.yml  # PR validation & plan
│       ├── terraform-sit.yml              # SIT/Dev deployment
│       ├── terraform-staging.yml          # Staging deployment
│       ├── terraform-prod.yml             # Production deployment
│       ├── terraform-destroy.yml          # Destroy workflow
│       ├── issue-new-repo.yml             # New repo issue handler (validates org + name)
│       ├── issue-team-member.yml          # Team member issue handler
│       ├── issue-copilot-license.yml      # Copilot license issue handler
│       ├── issue-archive-repo.yml         # Archive repo issue handler
│       └── issue-ghes-migration.yml       # GHES → GHEC migration handler
│
├── scripts/
│   ├── add_repo_to_yaml.py               # Parses issue form → updates repositories.yaml
│   ├── add_org_to_yaml.py                # Parses issue form → updates organizations.yaml
│   ├── archive_repo_in_yaml.py           # Parses issue form → updates archive-requests.yaml
│   ├── create_codeowners.py              # Creates CODEOWNERS file via API
│   ├── manage_copilot_license.py         # Manages Copilot licenses via API
│   ├── manage_team_members.py            # Manages team memberships via API
│   └── ghes_migrate.py                   # GHES → GHEC migration orchestrator
│
├── data/
│   ├── repositories.yaml                  # Repository definitions (YAML source of truth)
│   ├── organizations.yaml                 # Organization definitions
│   ├── archive-requests.yaml              # Archive request definitions
│   ├── migration-manifests.yaml           # GHES → GHEC migration tracking
│   ├── teams.yaml                         # Team & membership definitions
│   ├── copilot-licenses.yaml              # Copilot license assignments
│   └── org-settings.yaml                  # Organization-level settings
│
├── modules/
│   ├── github-repo/                       # Repository management module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── github-team/                       # Team & membership module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── github-copilot/                    # Copilot license module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── github-org-settings/               # Org settings module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── github-repo-settings/              # Repo settings module (granular)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── github-archive-repo/               # Repository archival module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── github-migration/                  # GHES → GHEC migration module
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
├── environments/
│   ├── sit/                               # Dev / SIT environment
│   │   ├── main.tf                        # Calls modules
│   │   ├── variables.tf
│   │   └── terraform.tfvars
│   ├── staging/                           # Staging environment
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars
│   └── prod/                              # Production environment
│       ├── main.tf
│       ├── variables.tf
│       └── terraform.tfvars
│
├── backend.tf                             # Remote state configuration
├── docs/
│   ├── architecture.md                    # This document
│   └── preparation-plan-and-execution-plan.md
└── .gitignore
```

---

## 4. Module Design

### 4.1 github-repo (Repository Management)

**Purpose:** Create and configure GitHub repositories with all settings.

```hcl
# environments/<env>/main.tf
module "github_repos" {
  source = "../../modules/github-repo"

  repositories   = var.repositories
  default_topics = var.default_topics
}
```

**Manages:**
- Repository creation (name, description, visibility)
- Feature toggles (issues, projects, wiki, discussions)
- Merge strategies (squash, merge, rebase)
- Branch protection rules
- Security scanning (advanced security, secret scanning, push protection)
- Default branch enforcement (`main`)
- Dependabot security updates
- Repository rulesets
- Autolink references
- Deploy keys

### 4.2 github-team (Team & Membership Management) — _Planned_

**Purpose:** Manage teams, nested teams, and user memberships.

```hcl
# environments/<env>/main.tf
module "github_teams" {
  source = "../../modules/github-team"

  teams = var.teams
}
```

**Will Manage:**
- Team creation (`github_team`)
- Team membership — add/remove users (`github_team_membership`)
- Team repository access (`github_team_repository`)
- Nested team hierarchy
- Team privacy settings

### 4.3 github-copilot (Copilot License Management) — _Planned_

**Purpose:** Assign and revoke GitHub Copilot licenses.

```hcl
# environments/<env>/main.tf
module "github_copilot" {
  source = "../../modules/github-copilot"

  copilot_seats = var.copilot_seats
}
```

**Will Manage:**
- Copilot seat assignment per user/team (`github_copilot_seat_assignment` or API-based)
- License tracking and reporting
- Policy enforcement (allow/deny list)

### 4.4 github-org-settings (Organization Settings) — _Planned_

**Purpose:** Manage organization-level configuration.

```hcl
# environments/<env>/main.tf
module "github_org_settings" {
  source = "../../modules/github-org-settings"

  org_settings = var.org_settings
}
```

**Will Manage:**
- Organization security settings (`github_organization_settings`)
- Default repository permissions
- Member privileges
- Two-factor authentication enforcement
- Organization webhooks
- Actions permissions and runner groups

### 4.5 github-repo-settings (Repository Settings) — _Planned_

**Purpose:** Granular repository settings management separate from creation.

```hcl
# environments/<env>/main.tf
module "github_repo_settings" {
  source = "../../modules/github-repo-settings"

  repo_settings = var.repo_settings
}
```

**Will Manage:**
- Collaborator management
- Webhook configuration
- Environment & secrets management
- Actions permissions per repo
- Custom properties

### 4.6 github-migration (GHES → GHEC Migration) — _Planned_

**Purpose:** Orchestrate end-to-end migration of repositories from GitHub Enterprise Server (GHES) to GitHub Enterprise Cloud (GHEC).

```hcl
# environments/<env>/main.tf
module "github_migration" {
  source = "../../modules/github-migration"

  migrations = var.migrations
}
```

**Migration Approach:**

The migration leverages **GitHub Enterprise Importer (GEI)** CLI (`gh gei`) as the primary tool, supplemented by the GitHub REST/GraphQL API for metadata and validation.

```
┌───────────────────────────────────────────────────────────────────────┐
│                       GHES → GHEC Migration Flow                     │
│                                                                       │
│  ┌─────────────┐    ┌──────────────┐    ┌─────────────────────────┐  │
│  │ GHES Server │    │  Migration   │    │   GHEC (Target)         │  │
│  │             │    │  Pipeline    │    │                         │  │
│  │  ┌───────┐  │    │              │    │  ┌───────────────────┐  │  │
│  │  │ Repo  │──┼───▶│ 1. Validate  │───▶│  │  New Repo         │  │  │
│  │  │ Code  │  │    │ 2. Export    │    │  │  (code + history) │  │  │
│  │  └───────┘  │    │ 3. Import    │    │  └───────────────────┘  │  │
│  │  ┌───────┐  │    │ 4. Verify    │    │  ┌───────────────────┐  │  │
│  │  │ PRs   │──┼───▶│ 5. Cutover   │───▶│  │  PRs + Issues     │  │  │
│  │  │Issues │  │    │ 6. Cleanup   │    │  │  (metadata)       │  │  │
│  │  └───────┘  │    │              │    │  └───────────────────┘  │  │
│  │  ┌───────┐  │    │              │    │  ┌───────────────────┐  │  │
│  │  │Branch │──┼───▶│              │───▶│  │  Branch protection│  │  │
│  │  │Protect│  │    │              │    │  │  & settings       │  │  │
│  │  └───────┘  │    │              │    │  └───────────────────┘  │  │
│  └─────────────┘    └──────────────┘    └─────────────────────────┘  │
└───────────────────────────────────────────────────────────────────────┘
```

**Will Manage:**
- Source repository validation (exists, accessible, not archived)
- Repository migration via `gh gei migrate-repo`
- Git history, branches, tags migration
- Pull requests and issues migration (metadata)
- Team and collaborator access re-mapping
- Branch protection rules re-application
- Webhooks re-configuration (manual review)
- Source repo archival post-migration
- Migration status tracking in `data/migration-manifests.yaml`
- Rollback support (delete target if migration fails)

**What Gets Migrated:**

| Asset | Auto-Migrated | Manual Step |
|-------|:------------:|:-----------:|
| Git history (commits, branches, tags) | ✅ | — |
| Pull requests (open + closed) | ✅ | — |
| Issues (open + closed) | ✅ | — |
| Releases | ✅ | — |
| Wikis | ✅ | — |
| Repository settings | ✅ | — |
| Branch protection rules | ⚠️ Partial | Re-apply via Terraform |
| Webhooks | ❌ | Reconfigure URLs |
| GitHub Actions workflows | ✅ (as code) | Update runner labels |
| Secrets & Variables | ❌ | Re-create in GHEC |
| GitHub Pages config | ❌ | Reconfigure |
| Deploy keys | ❌ | Re-create |
| Collaborator permissions | ⚠️ Partial | Verify team mappings |
| LFS objects | ✅ | — |
| CODEOWNERS | ✅ (as code) | Verify team slugs |

**Pre-Migration Checklist (Automated):**
1. GHES repo exists and is accessible
2. Target org exists in GHEC
3. No naming conflict in target org
4. GHES repo is not already archived
5. GEI CLI is installed and authenticated
6. GHES PAT has `repo`, `admin:org` scopes
7. GHEC PAT has `repo`, `admin:org`, `workflow` scopes

### 4.7 github-archive-repo (Repository Archival) — _In Progress_

**Purpose:** Archive repositories with validation, preserving settings.

```hcl
# environments/<env>/main.tf
module "github_archive" {
  source = "../../modules/github-archive-repo"

  archive_requests = { for k, v in var.archive_requests : k => v if v.organization == var.organization }
}
```

**Manages:**
- Repository archival with reason tracking
- Pre-archive validation (repo exists, not already archived)
- Lock repository option
- Description update with archive reason
- Multi-org filtering

---

## 5. Environments

| Environment | Purpose | Branch Trigger | Approval |
|-------------|---------|---------------|----------|
| **SIT (Dev)** | Integration testing, rapid iteration | `develop`, `feature/*` | Auto |
| **Staging** | Pre-production validation | `release/*` | 1 reviewer |
| **Production** | Live GitHub Enterprise configuration | `main` | 2 reviewers |

### 5.1 Environment Configuration Differences

| Setting | SIT | Staging | Production |
|---------|-----|---------|------------|
| Branch protection | Optional | Required | Strict |
| Required approvals | 0–1 | 2 | 2+ |
| Security scanning | Enabled | Enabled | Enforced |
| Signed commits | Optional | Optional | Required |
| Dependabot | Enabled | Enabled | Enforced |
| Archive on destroy | Enforced | Enforced | Enforced |

---

## 6. CI/CD Workflow Architecture

### 6.1 Issue-Driven Repository Creation Flow

```
┌──────────────────┐
│  User creates    │
│  GitHub Issue    │
│  using template  │
│  "New Repo       │
│   Request"       │
│  (selects org)   │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐     ┌──────────────────┐
│  GitHub Actions  │────▶│  Validate:       │
│  issue handler   │     │  1. Org exists   │
│  (on: issues     │     │  2. Naming conv  │
│   opened)        │     │     <org>-<name> │
└──────────────────┘     │  3. No duplicate │
                         └────────┬─────────┘
                         ┌────────▼─────────┐
                    NO   │  Validation      │   YES
                 ┌───────│  Passed?         │────────┐
                 │       └──────────────────┘        │
                 ▼                                   ▼
        ┌────────────────┐              ┌────────────────────┐
        │  Comment on    │              │  Parse issue form  │
        │  issue with    │              │  Extract YAML      │
        │  error details │              │  config values     │
        │  Label: invalid│              └────────┬───────────┘
        └────────────────┘                       │
                                        ┌────────▼───────────┐
                                        │  Update            │
                                        │  data/             │
                                        │  repositories.yaml │
                                        └────────┬───────────┘
                                                 │
                                        ┌────────▼───────────┐
                                        │  Create PR with    │
                                        │  changes           │
                                        │  Link to issue     │
                                        └────────┬───────────┘
                                                 │
                                        ┌────────▼───────────┐
                                        │  Auto-trigger:     │
                                        │  • YAML validation │
                                        │  • terraform fmt   │
                                        │  • terraform plan  │
                                        └────────┬───────────┘
                                                 │
                                        ┌────────▼───────────┐
                                        │  Team reviews &    │
                                        │  approves PR       │
                                        └────────┬───────────┘
                                                 │
                                        ┌────────▼───────────┐
                                        │  PR merged to main │
                                        └────────┬───────────┘
                                                 │
                              ┌──────────────────┼──────────────────┐
                              │                  │                  │
                     ┌────────▼──────┐  ┌────────▼──────┐  ┌───────▼───────┐
                     │ terraform     │  │ terraform     │  │ terraform     │
                     │ apply (SIT)   │  │ apply (STG)   │  │ apply (PROD)  │
                     └────────┬──────┘  └────────┬──────┘  └───────┬───────┘
                              │                  │                 │
                              └──────────────────┼─────────────────┘
                                                 │
                                        ┌────────▼───────────┐
                                        │  Close issue with  │
                                        │  success message   │
                                        │  & repo URL        │
                                        └────────────────────┘
```

### 6.2 Workflow Summary

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `issue-new-repo.yml` | `issues.opened` (label: `new-repo-request`) | Validate org + name → parse issue → create PR |
| `repo-validation-terraform.yml` | `pull_request` | YAML lint, `terraform fmt`, `terraform plan` |
| `terraform-sit.yml` | PR merge / manual | `terraform apply` on SIT |
| `terraform-staging.yml` | After SIT success / manual | `terraform apply` on Staging |
| `terraform-prod.yml` | After Staging success / manual approval | `terraform apply` on Production |
| `terraform-destroy.yml` | Manual dispatch | Controlled teardown |
| `issue-team-member.yml` | `issues.opened` (label: `team-member-request`) | Parse → update teams.yaml → PR |
| `issue-copilot-license.yml` | `issues.opened` (label: `copilot-license-request`) | Parse → update copilot.yaml → PR |
| `issue-archive-repo.yml` | `issues.opened` (label: `archive-repo-request`) | Validate → archive repo via Terraform |
| `issue-ghes-migration.yml` | `issues.opened` (label: `ghes-migration-request`) | Validate → export GHES → import GHEC → verify |

---

## 7. Data Flow — YAML as Source of Truth

All resource definitions live in `data/*.yaml` files. Terraform reads these YAML files and provisions resources accordingly.

```
data/repositories.yaml          →  modules/github-repo
data/organizations.yaml         →  modules/github-org
data/archive-requests.yaml      →  modules/github-archive-repo
data/migration-manifests.yaml   →  modules/github-migration
data/teams.yaml                 →  modules/github-team
data/copilot-licenses.yaml      →  modules/github-copilot
data/org-settings.yaml          →  modules/github-org-settings
```

### 7.1 Example: data/repositories.yaml

```yaml
repositories:
  maybank-frontend-app:
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
```

---

## 8. Security Architecture

### 8.1 Authentication

| Component | Method |
|-----------|--------|
| Terraform → GitHub API | GitHub App or PAT (stored as GitHub Actions secret) |
| GitHub Actions → Terraform | `GITHUB_TOKEN` + `TF_VAR_github_token` |
| State Backend | Encrypted S3 / Azure Blob with DynamoDB lock |

### 8.2 Enforced Security Policies (Hardcoded in Module)

These settings are **enforced at the module level** and cannot be overridden by environment variables:

| Policy | Enforced Value | Rationale |
|--------|---------------|-----------|
| `archive_on_destroy` | `true` | Prevent accidental data loss |
| `security_and_analysis` | `enabled` | Mandatory security scanning |
| Default branch | `main` | Consistent branching strategy |
| Dependabot security updates | `enabled` | Automated vulnerability patching |

### 8.3 Secrets Management

- GitHub Actions secrets for Terraform provider authentication
- No secrets in YAML data files or tfvars
- Sensitive variables marked with `sensitive = true` in Terraform

---

## 9. State Management

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "<state-bucket>"
    key            = "github-repos/<env>/terraform.tfstate"
    region         = "ap-southeast-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

- One state file per environment
- State locking via DynamoDB
- Encrypted at rest

---

## 10. Future Roadmap

| Phase | Capability | Target |
|-------|-----------|--------|
| Phase 1 | Repository automation (creation, archival, CODEOWNERS) | ✅ |
| Phase 2 | Team & membership management | 🔜 |
| Phase 3 | Copilot license management | 🔜 |
| Phase 4 | **GHES → GHEC repository migration** | 🔜 |
| Phase 5 | Organization settings | 🔜 |
| Phase 6 | Repository settings (granular) | 🔜 |
| Phase 7 | Audit logging & compliance reporting | 🔜 |
| Phase 8 | Self-service portal (GitHub Pages) | 🔜 |

---

## 11. Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| **Modular Terraform** | Each concern (repos, teams, copilot) is a separate module for reusability and isolation |
| **YAML data files** | Human-readable, easy to review in PRs, decoupled from Terraform logic |
| **Issue-driven workflows** | Self-service for developers, audit trail via issues & PRs |
| **Enforced security defaults** | Critical settings hardcoded in modules to prevent misconfiguration |
| **Three environments** | Progressive deployment with increasing strictness |
| **Archive on destroy** | Repositories are archived instead of deleted to prevent data loss |
| **GEI for migration** | GitHub Enterprise Importer is the officially supported tool for GHES → GHEC migration |
| **Migration tracking** | All migration state tracked in YAML for auditability and rollback |
