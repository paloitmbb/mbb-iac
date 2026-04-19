# GitHub Automation Design Plan

**Project:** Maybank GitHub Enterprise Cloud (GHEC) Automation  
**Audience:** Management  
**Classification:** Internal

---

## Summary

This document describes the design for automating GitHub Enterprise Cloud (GHEC) application onboarding and administration. Prior to this initiative, all repository provisioning, team management, and environment migrations were performed manually by the DevSecOps team, resulting in inconsistent configurations, slow turnaround times, and limited audit trails.

The automation replaces these manual processes with structured, issue-driven workflows that enforce governance at every step — from request validation through to execution — with full traceability via GitHub's native audit mechanisms.

---

## Solution Intent

| Objective | Description |
|-----------|-------------|
| **Standardise onboarding** | All application teams follow a consistent, repeatable process to request and receive GitHub resources |
| **Enforce governance** | Every change requires validation and mandatory approval before execution |
| **Provide auditability** | Every action is traceable to a requestor, an approver, and a workflow run |
| **Reduce toil** | Eliminate manual, error-prone steps performed by the DevSecOps team |
| **Enable self-service** | Application teams can raise requests directly without DevSecOps intervention for routine operations |

---

## Solution Design

All workflows follow a common pattern:

1. A team member raises a **GitHub Issue** using a structured request form
2. The workflow is automatically triggered and **validates** the request
3. If validation passes, the workflow enters an **approval gate** — a designated reviewer must approve before any change is applied
4. Upon approval, the workflow **executes** the change and posts a summary back to the issue
5. The issue is automatically closed on success, providing a permanent audit record

The combination of the **issue form** (requestor identity), **approval gate** (approver identity), and **workflow run log** (execution evidence) forms the audit trail for every change.

---

### New Repository Request

**Purpose:** Allow application teams to request a new GitHub repository to be provisioned in the GHEC organisation.

**Trigger:** A GitHub Issue labelled `repo-request` is opened using the repository request form.

#### Workflow Stages

| Stage | Name | Description |
|-------|------|-------------|
| 1 | **Validate Request** | Parse the issue form and run validation checks against the submitted data |
| 2 | **Approval Gate** | Pause execution; a DevSecOps reviewer must approve before proceeding |
| 3 | **Create Configuration PR** | Generate a pull request adding the new repository definition to the infrastructure codebase |
| 4 | **Apply Infrastructure** | On PR merge, apply the configuration to provision the repository in GHEC |

#### Validation Checks

| Check | Description | Fail Behaviour |
|-------|-------------|----------------|
| Repository name format | Name must contain only alphanumeric characters, hyphens, and underscores | Request rejected; issue commented with error |
| Repository name uniqueness | Repository must not already exist in the organisation | Request rejected |
| Team access validity | Each specified team must already exist in the organisation | Request rejected |
| Business justification provided | A non-empty justification must be present | Request rejected |
| Default branch name | Must be a valid Git branch name | Defaults to `main` if not specified |

---

### Team Management Request

**Purpose:** Allow authorised users to manage GitHub teams and their memberships without requiring direct admin access.

**Trigger:** A GitHub Issue labelled `team-request` is opened using the team management form.

#### Supported Request Types

- Create new team
- Request team maintainer role
- Remove team maintainer role
- Give team access to a repository
- Remove team access to a repository

#### Workflow Stages

| Stage | Name | Description |
|-------|------|-------------|
| 1 | **Validate Request** | Parse the issue form, identify the request type, and run applicable validation checks |
| 2 | **Approval Gate** | Pause execution; a DevSecOps reviewer must approve before proceeding |
| 3 | **Execute Request** | Apply the requested team change via the GitHub API and post the result to the issue |

#### Validation Checks

| Check | Applies To | Description | Fail Behaviour |
|-------|-----------|-------------|----------------|
| Request type is valid | All | Must be one of the supported request types | Request rejected |
| Team name format | All | Must contain only alphanumeric characters, hyphens, underscores, and periods | Request rejected |
| Team exists | All except *Create* | Team must already exist in the organisation | Request rejected |
| Team does not exist | *Create* only | Team must not already exist | Request rejected |
| User exists on GitHub | Maintainer requests | Specified username must be a valid GitHub account | Request rejected |
| User is organisation member | Maintainer requests | Specified user must already be a member of the GHEC organisation | Request rejected |
| Repository exists | Repository access requests | Target repository must exist in the organisation | Request rejected |

---

### GHES to GHEC Migration Request

**Purpose:** Migrate a repository from GitHub Enterprise Server (GHES) to GitHub Enterprise Cloud (GHEC), transferring git history, pull requests, issues, and other repository data.

**Trigger:** A GitHub Issue labelled `ghec-migration-request` is opened using the migration request form.

#### Workflow Stages

| Stage | Name | Description |
|-------|------|-------------|
| 1 | **Validate Request** | Parse the issue form and verify both source and target repositories are accessible and correctly specified |
| 2 | **Pre-Migration Analysis** | Collect and surface a full inventory of the source repository — branches, tags, secrets, variables, webhooks, and security settings — for reviewers to assess before approval |
| 3 | **Approval Gate** | Pause execution; a designated migration approver must review the pre-migration report and approve |
| 4 | **Execute Migration** | Run the GitHub Enterprise Importer (GEI) tool to migrate the repository to GHEC |
| 5 | **Post-Migration Setup** | Apply target organisation standards — branch protection rules, team access mappings, CODEOWNERS injection, and security settings |
| 6 | **Cutover & Cleanup** | Optionally archive the source repository; post final migration report; close the issue |

#### Validation Checks

| Check | Description | Fail Behaviour |
|-------|-------------|----------------|
| Source repository accessible | Source PAT can reach the source repository | Request rejected |
| Target repository name available | Target repository name must not already exist in the GHEC organisation | Request rejected |
| Target organisation valid | Target organisation must be the approved GHEC organisation | Request rejected |
| Migration form complete | All mandatory form fields must be filled | Request rejected |

#### Pre-Migration Report (surfaces to approver)

| Data Point | Purpose |
|------------|---------|
| Repository size, branch count, tag count | Assess migration scope |
| Open pull requests and issues | Understand in-flight work |
| Protected branches | Verify branch protection will be re-applied post-migration |
| Variable and secret names | Identify manual remediation required (secret values cannot be migrated) |
| Webhook URLs | Identify integrations requiring manual re-creation |
| CODEOWNERS presence | Flag if a default CODEOWNERS will be injected |
| Security scanning status | Confirm security posture of source before migration |

---

### Copilot Seat Request

**Purpose:** Allow teams to request GitHub Copilot seat assignments for users or teams within the GHEC organisation.

**Trigger:** A GitHub Issue using the Copilot seat request form is opened.

> **Status:** Planned — not yet implemented.

#### Workflow Stages

| Stage | Name | Description |
|-------|------|-------------|
| 1 | **Validate Request** | Verify the requested users or teams exist in the organisation and are eligible for a Copilot seat |
| 2 | **Approval Gate** | Pause execution; a designated approver (e.g., cost centre owner) must approve the seat allocation |
| 3 | **Execute Assignment** | Assign or revoke Copilot seats as requested and post a summary to the issue |

#### Validation Checks

| Check | Description |
|-------|-------------|
| User or team exists | Requested assignees must exist in the GHEC organisation |
| Seat availability | Confirm available Copilot licence capacity before proceeding |
| Request type valid | Must be either an assignment or a revocation request |

---

### Archive Repository

**Purpose:** Allow teams to request the archival of a repository that is no longer actively maintained, preserving its history in a read-only state.

**Trigger:** A GitHub Issue using the archive repository request form is opened.

> **Status:** Planned — not yet implemented.

#### Workflow Stages

| Stage | Name | Description |
|-------|------|-------------|
| 1 | **Validate Request** | Verify the repository exists and is not already archived |
| 2 | **Approval Gate** | Pause execution; the repository owner and a DevSecOps reviewer must approve |
| 3 | **Execute Archival** | Set the repository to archived state and post a confirmation to the issue |

#### Validation Checks

| Check | Description |
|-------|-------------|
| Repository exists | The named repository must exist in the organisation |
| Repository not already archived | Must not be in an already-archived state |
| Requester is authorised | Requestor must be a maintainer or admin of the repository |
| Business justification provided | A non-empty justification must be present |
