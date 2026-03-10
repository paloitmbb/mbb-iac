# MBB GHES → GHEC Migration — Implementation Plan

## 1. Overview

This document describes the implementation plan for the **GitHub Enterprise Server (GHES) → GitHub Enterprise Cloud (GHEC) repository migration** solution. The system is driven by a GitHub Issues form and an automated GitHub Actions workflow that uses the **GitHub Enterprise Importer (GEI) CLI** to migrate repositories from a GHES 3.15.3 instance to GitHub Enterprise Cloud.

> **⚠️ Architecture Notes:**
>
> - **Source**: GitHub Enterprise Server (GHES) **3.15.3**
> - **Target**: GitHub Enterprise Cloud (GHEC) on GitHub.com
> - **Blob Storage (Mandatory)**: GHES migrations require Azure Blob Storage (or AWS S3) as an intermediary. The GEI CLI uploads migration archives to blob storage, and GHEC reads from it. See [GitHub Docs — Set up blob storage](https://docs.github.com/en/enterprise-server@3.15/migrations/using-github-enterprise-importer/migrating-between-github-products/migrating-repositories-from-github-enterprise-server-to-github-enterprise-cloud#step-4-set-up-blob-storage).
> - **GHES Management Console**: Migrations must be enabled in the GHES Management Console with blob storage configured and tested before use (see §13).
> - **Target repo must already exist** — the workflow validates that the target repository exists on GHEC before proceeding (does not create a new repo)
> - **Full branch protection migration** — branch protection rules are migrated from source with fallback probing, not just default branch protection
> - **Rulesets migration** — repository and org-level rulesets are migrated (repo-level first, org-level fallback)
> - **Actions permissions migration** — permissions policy, selected actions, and workflow permissions are migrated
> - **Environments migration** — environments and their variables are migrated from source
> - **Repository-level Actions variables migration** — repo-level Actions variables are migrated
> - **Secret names listing** — secret names are listed for manual re-creation (values cannot be read via API)
> - **GHAS migration expanded** — includes code scanning default setup, secret scanning non-provider patterns, validity checks

### Architecture Diagram

```
┌──────────────┐         ┌──────────────────────┐         ┌─────────────┐
│  GHES 3.15.3 │────────►│  Azure Blob Storage  │────────►│    GHEC     │
│  (source)    │  upload  │  (intermediary)       │  read   │  (target)   │
└──────────────┘         └──────────────────────┘         └─────────────┘
       │                                                         ▲
       │              GEI CLI orchestrates both legs             │
       └─────────────────────────────────────────────────────────┘
```

### Components

| Component | Path | Purpose |
|-----------|------|---------|
| Issue Template | `.github/ISSUE_TEMPLATE/ghes-migration-request.yml` | Self-service form for users to request a GHES → GHEC repository migration |
| Workflow | `.github/workflows/issue-ghes-migration.yml` | 7-job pipeline that validates, migrates, configures, verifies, and closes the request |

---

## 2. Prerequisites

Before the solution can be used, the following must be in place:

| # | Prerequisite | Details |
|---|-------------|---------|
| 1 | **GHES instance (v3.15.3)** | Source GitHub Enterprise Server must be accessible from the workflow runner; GitHub Actions must be enabled on the GHES instance |
| 2 | **Blob storage configured** | Azure Blob Storage (or AWS S3) must be provisioned and configured in the GHES Management Console under **Migrations** (see §13) |
| 3 | **GH_SOURCE_PAT** secret | A Personal Access Token on the **GHES instance** with **read** access to the source repository (`repo`, `admin:org` scopes) |
| 4 | **GH_TARGET_PAT** secret | A Personal Access Token on **GitHub.com (GHEC)** with **write/admin** access to the target organization (`repo`, `admin:org`, `workflow` scopes) |
| 5 | **AZURE_STORAGE_CONNECTION_STRING** secret | Connection string for the Azure Blob Storage account used as the migration intermediary |
| 6 | **Target org exists on GHEC** | The target GitHub.com (GHEC) organization must already be created |
| 7 | **Target repo must already exist** | The target repository must be pre-created on GHEC before requesting migration |
| 8 | **`migration-approval` environment** | A GitHub environment with required reviewers configured for the approval gate |

---

## 3. Issue Template — `ghes-migration-request.yml`

### 3.1 Form Structure

The issue template collects all information needed to execute a GHES → GHEC migration:

| Section | Field | Type | Required | Validation |
|---------|-------|------|----------|------------|
| **Source (GHES)** | Source GHES URL | `input` | Yes | Must be a valid HTTPS URL to the GHES instance (e.g., `https://ghes.example.com`) |
| | Source Organization | `input` | Yes | — |
| | Source Repository Name | `input` | Yes | — |
| **Target (GHEC)** | Target Organization | `input` | Yes | Must exist on GitHub.com |
| | Target Repository Name | `input` | Yes | Regex: `^[a-z0-9]+(-[a-z0-9]+)+$` |
| | Target Visibility | `dropdown` | Yes | `private` (default), `internal`, `public` |
| **Migration Options** | Checkboxes | `checkboxes` | No | 5 options (commit history, PRs, issues, releases, archive source) |
| **Access** | Admins | `input` | Yes | Comma-separated GitHub usernames |
| | Team Access Mappings | `textarea` | No | Format: `source-team → target-team : permission` |
| **Other** | Justification | `textarea` | Yes | Free-text reason for migration |
| | Confirmation | `checkboxes` | Yes | 3 mandatory confirmations |

### 3.2 Naming Convention

Target repository names must follow the pattern:

```
<org><region>-<dept>-<type>[tiering-optional]-<name>
```

Example: `mbbmy-dbdo-app-mae-mobile`

### 3.3 Implementation Steps

| # | Task | Status |
|---|------|--------|
| 1 | Define issue template YAML with all fields | Done |
| 2 | Add regex validation for target repo naming | Done |
| 3 | Add mandatory confirmation checkboxes | Done |
| 4 | Add prerequisite documentation in the template header | Done |

---

## 4. Workflow — `issue-ghes-migration.yml`

### 4.1 Trigger

```yaml
on:
  issues:
    types: [opened]
```

The workflow triggers when an issue is opened and filters by title prefix `[GHES Migration]` (set automatically by the issue template).

### 4.2 Job Pipeline

The workflow consists of **7 sequential jobs** with dependency gates:

```
┌──────────┐    ┌──────────┐    ┌───────────────┐    ┌─────────┐
│ validate │───►│ approval │───►│ pre-migration │───►│ migrate │
└──────────┘    └──────────┘    └───────────────┘    └────┬────┘
                                                          │
                                                          ▼
                                ┌─────────────┐    ┌──────────────────┐
                                │   verify     │◄───│ post-migration   │
                                └──────┬──────┘    └──────────────────┘
                                       │
                                       ▼
                                ┌──────────┐    ┌─────────────┐
                                │ cutover  │───►│ close-issue │
                                └──────────┘    └─────────────┘
```

---

### 4.3 Job 1: Validate (`validate`)

**Purpose:** Parse the issue body, extract all fields, and validate them against the source GHES instance and target GHEC organization.

| # | Step | Description | Implementation Detail |
|---|------|-------------|----------------------|
| 1 | Checkout | Clone the repository | `actions/checkout@v4` |
| 2 | Parse Issue Form | Extract fields from issue body using regex | `actions/github-script@v7` with custom JS parsing functions (`extractField`, `extractTextarea`, `extractCheckboxes`) |
| 3 | Display parsed values | Log all parsed values for debugging | Shell `echo` statements |
| 4 | Validate required fields | Check all mandatory fields are non-empty | Shell script with error accumulation |
| 5 | Validate GHES connectivity | Check URL format and connectivity to the source GHES instance | `curl` to `${GHES_URL}/api/v3/meta` with `GH_SOURCE_PAT` |
| 6 | Validate source and target repos | Combined step: (a) check source repo exists on GHES (`GET ${GHES_URL}/api/v3/repos/{org}/{repo}`), check if archived; (b) validate target org on GHEC (`GET https://api.github.com/orgs/{org}`); (c) check target repo exists on GHEC (`GET https://api.github.com/repos/{org}/{repo}` — must return 200) | Error accumulation pattern — all checks run, all errors reported together |
| 7 | Post validation results | Post detailed comment to issue | `actions/github-script@v7` — adds labels (`validation-passed` or `validation-failed`) |
| 8 | Comment validation passed | Summary table posted to issue | `peter-evans/create-or-update-comment@v4` |
| 9 | Generate validation summary | Write GitHub Actions job summary | `core.summary.addRaw().write()` |
| 10 | Label as in-progress | Add `in-progress` label to issue | `gh issue edit --add-label` |

**Outputs propagated to downstream jobs:**

- `source_ghes_url`, `source_organization`, `source_repo`, `target_organization`, `target_repo`
- `target_visibility`, `migration_options`, `admins`, `team_mappings`, `justification`
- `issue_number`

---

### 4.4 Job 2: Approval Gate (`approval`)

**Purpose:** Pause the workflow and require manual approval before proceeding with the migration.

| # | Step | Description |
|---|------|-------------|
| 1 | Comment approval requested | Post comment with migration summary asking for review |
| 2 | Wait for approval | GitHub environment protection rule (`migration-approval`) blocks until a reviewer approves |
| 3 | Comment approval granted | Post confirmation comment |

**Implementation Requirements:**

- Create a GitHub environment named `migration-approval`
- Add required reviewers (team leads, admins) to the environment
- Optionally configure a wait timer

---

### 4.5 Job 3: Pre-Migration Setup (`pre-migration`)

**Purpose:** Record the source repository's current state on GHES for post-migration verification.

| # | Step | Description | API Endpoint |
|---|------|-------------|---------------------|
| 1 | Parse migration options | Extract `archive_source` flag from checkboxes | String match on `"Archive source repository"` |
| 2 | Record source state | Capture branch count, tag count, HEAD SHA, default branch | `GET ${GHES_URL}/api/v3/repos/{org}/{repo}`, `/branches`, `/tags`, `/branches/{default}` |
| 3 | Comment pre-migration state | Post metrics table to issue | `peter-evans/create-or-update-comment@v4` |

**Outputs:**

- `source_branches`, `source_tags`, `source_head_sha`, `source_default_branch`, `archive_source`

---

### 4.6 Job 4: Execute GEI Migration (`migrate`)

**Purpose:** Run the GitHub Enterprise Importer CLI to migrate the repository from GHES to GHEC via blob storage.

| # | Step | Description |
|---|------|-------------|
| 1 | Install GEI CLI | `gh extension install github/gh-gei` |
| 2 | Run GEI migration | Execute `gh gei migrate-repo` with GHES source, blob storage, and target parameters |
| 3 | Comment migration result | Post success/failure with GEI output |

**GEI Command:**

```bash
gh gei migrate-repo \
  --github-source-org "$SRC_ORG" \
  --source-repo "$SRC_REPO" \
  --github-target-org "$TGT_ORG" \
  --target-repo "$TGT_REPO" \
  --target-repo-visibility "$VISIBILITY" \
  --ghes-api-url "${GHES_URL}/api/v3" \
  --azure-storage-connection-string "$AZURE_STORAGE_CONNECTION_STRING" \
  --verbose
```

**Environment Variables:**

| Variable | Source |
|----------|--------|
| `GH_SOURCE_PAT` | `secrets.GH_SOURCE_PAT` (GHES PAT) |
| `GH_PAT` | `secrets.GH_TARGET_PAT` (GHEC PAT) |
| `AZURE_STORAGE_CONNECTION_STRING` | `secrets.AZURE_STORAGE_CONNECTION_STRING` |

---

### 4.7 Job 5: Post-Migration Setup (`post-migration`)

**Purpose:** Configure the target GHEC repository with proper access, protection rules, security settings, environments, variables, and report secrets requiring manual re-creation.

| # | Step | Description | API Used |
|---|------|-------------|----------|
| 1 | Wait 15s | Let GHEC finalize the import | `sleep 15` |
| 2 | Add admin collaborators | Iterate comma-separated admin list, add each as admin on GHEC | `PUT https://api.github.com/repos/{org}/{repo}/collaborators/{user}` |
| 3 | Apply team access mappings | Parse `source → target : permission` format, apply each on GHEC | `PUT https://api.github.com/orgs/{org}/teams/{team}/repos/{org}/{repo}` |
| 4 | Migrate branch protection rules | Read from GHES source (`${GHES_URL}/api/v3/repos/...`), apply to GHEC target. Extract migratable settings (status checks, PR reviews, enforce admins, linear history, force pushes, deletions, block creations, conversation resolution, fork syncing, required signatures), skip actor-specific settings (push restrictions, dismissal restrictions, bypass allowances, lock branch, required deployments). Non-migratable settings tracked in `BRANCH_PROTECTION_MANUAL` env var for issue comment | Source: `GET ${GHES_URL}/api/v3/repos/{org}/{repo}/branches/{branch}/protection`; Target: `PUT https://api.github.com/repos/{org}/{repo}/branches/{branch}/protection` |
| 5 | Migrate rulesets | From GHES source: repo-level first, org-level fallback. Cleans org-specific fields before creating on GHEC target | Source: `GET ${GHES_URL}/api/v3/repos/{org}/{repo}/rulesets`; Target: `POST https://api.github.com/repos/{org}/{repo}/rulesets` |
| 6 | Migrate Actions permissions | Read from GHES source, apply to GHEC target | Source: `GET ${GHES_URL}/api/v3/repos/{org}/{repo}/actions/permissions`; Target: `PUT https://api.github.com/repos/{org}/{repo}/actions/permissions` |
| 7 | Migrate environments | Read environments and variables from GHES source, create on GHEC (secrets cannot be read) | Source: `GET ${GHES_URL}/api/v3/repos/{org}/{repo}/environments`; Target: `PUT https://api.github.com/repos/{org}/{repo}/environments/{name}` |
| 8 | Migrate repo-level Actions variables | Paginated variable migration from GHES source to GHEC target | Source: `GET ${GHES_URL}/api/v3/repos/{org}/{repo}/actions/variables`; Target: `POST https://api.github.com/repos/{org}/{repo}/actions/variables` |
| 9 | List repo-level secret names | List Actions secrets, Dependabot secrets, and environment secrets from GHES (names only — values are unreadable via API) | `GET ${GHES_URL}/api/v3/repos/{org}/{repo}/actions/secrets`, `/dependabot/secrets`, `/environments/{name}/secrets` |
| 10 | Migrate GHAS permissions | Multi-step security migration (see §4.7.1) | Source: GHES API; Target: GHEC API |
| 11 | Comment results | Post comprehensive summary with manual action items | `peter-evans/create-or-update-comment@v4` |

#### 4.7.1 Advanced Security (GHAS) Migration Sub-steps

| Sub-step | Action | Source API (GHES) | Target API (GHEC) |
|----------|--------|-------------------|-------------------|
| 1 | Read source GHAS settings | `GET ${GHES_URL}/api/v3/repos/{org}/{repo}` → `security_and_analysis` | — |
| 2 | Enable Advanced Security on target (if enabled on source) | — | `PATCH https://api.github.com/repos/{org}/{repo}` with `advanced_security.status: "enabled"` |
| 3 | Apply Secret Scanning settings | — | `PATCH https://api.github.com/repos/{org}/{repo}` with `secret_scanning`, `push_protection`, `validity_checks`, `non_provider_patterns` |
| 4 | Enable Dependabot | — | `PUT https://api.github.com/repos/{org}/{repo}/vulnerability-alerts` + `PATCH` with `dependabot_security_updates` |
| 5 | Migrate Code Scanning default setup | `GET ${GHES_URL}/api/v3/repos/{org}/{repo}/code-scanning/default-setup` | `PATCH https://api.github.com/repos/{org}/{repo}/code-scanning/default-setup` |
| 6 | Check Security Manager teams | `GET ${GHES_URL}/api/v3/orgs/{org}/security-managers` | Informational only (org-level, manual re-config required) |

**Graceful degradation:** If any GHAS step fails, it is logged to `GHAS_MANUAL_FILE` and reported in the issue comment as requiring manual configuration. The job continues (does not fail hard). Similarly, non-migratable branch protection settings (actor-specific) are tracked in `BRANCH_PROTECTION_MANUAL` and reported.

---

### 4.8 Job 6: Verify Migration Integrity (`verify`)

**Purpose:** Compare source and target repository states to confirm migration fidelity.

| Check | Source | Target | Pass Criteria |
|-------|--------|--------|---------------|
| Branch count | `pre-migration.source_branches` | `GET /repos/{org}/{repo}/branches` on GHEC | Exact match |
| Tag count | `pre-migration.source_tags` | `GET /repos/{org}/{repo}/tags` on GHEC | Exact match |
| HEAD SHA | `pre-migration.source_head_sha` (first 7 chars) | `GET /repos/{org}/{repo}/branches/{default}` on GHEC | First 7 chars match |

**Output:** `verification_passed` = `true` / `false`

---

### 4.9 Job 7: Cutover & Cleanup (`cutover`)

**Purpose:** Archive the source repo on GHES (if requested) after successful verification.

| # | Step | Condition | Description |
|---|------|-----------|-------------|
| 1 | Checkout | Always | Clone repo for potential manifest updates |
| 2 | Archive source on GHES | `archive_source == 'true'` | `PATCH ${GHES_URL}/api/v3/repos/{org}/{repo}` with `{"archived": true, "description": "[MIGRATED TO GHEC]..."}` |

**Gate:** Only runs if `verify.verification_passed == 'true'`

**Note:** The migration manifest update step is currently commented out in the workflow.

---

### 4.10 Job 8: Close Issue (`close-issue`)

**Purpose:** Post a final success comment, generate a workflow summary, and close the issue.

| # | Step | Description |
|---|------|-------------|
| 1 | Generate apply summary | Write a detailed job summary with migration details, verification results, and next steps |
| 2 | Post success comment | Post comprehensive completion comment to issue with migration details table |
| 3 | Close issue | Close issue as `completed`, remove `in-progress` label, add `completed` label |

**Gate:** Runs only when `verify.verification_passed == 'true'` AND `cutover` succeeded or was skipped.

---

## 5. Secrets Configuration

| Secret Name | Scope | Required Permissions |
|-------------|-------|---------------------|
| `GITHUB_TOKEN` | Auto-provided | `issues: write`, `contents: read` |
| `GH_SOURCE_PAT` | Source GHES instance | `repo` (read), `admin:org` (read) on the GHES source organization |
| `GH_TARGET_PAT` | Target GitHub.com (GHEC) | `repo`, `admin:org`, `workflow`, `delete_repo` on the target GHEC org |
| `AZURE_STORAGE_CONNECTION_STRING` | Azure Blob Storage | Connection string for the blob storage account used as migration intermediary |

---

## 6. Environment Setup

| Environment Name | Purpose | Configuration |
|-----------------|---------|---------------|
| `migration-approval` | Gate between validation and execution | Add required reviewers (e.g., platform team leads). Optionally add a wait timer. |

---

## 7. Label Management

The workflow automatically manages the following labels:

| Label | Color | When Applied | When Removed |
|-------|-------|-------------|--------------|
| `ghes-to-ghec-migration` | — | On issue creation (via template) | Never |
| `validation-passed` | — | After successful validation | Never |
| `validation-failed` | — | After failed validation | Never |
| `in-progress` | `#FBCA04` | After validation passes | On issue close |
| `completed` | — | On successful migration | Never |

---

## 8. Error Handling Strategy

| Scenario | Behavior |
|----------|----------|
| Missing required fields | Issue comment with specific errors; workflow exits |
| Invalid GHES URL format | Issue comment with expected format; workflow exits |
| GHES instance unreachable | Issue comment with HTTP status; workflow exits |
| Source repo not found on GHES / archived | Issue comment explaining the problem; workflow exits |
| Target repo does not exist on GHEC | Issue comment asking user to create the target repo first; workflow exits |
| Blob storage misconfigured | GEI fails with storage error; issue comment with GEI output; workflow exits |
| `AZURE_STORAGE_CONNECTION_STRING` missing or invalid | GEI fails; issue comment with error details; workflow exits |
| GEI migration failure | Issue comment with GEI output; workflow exits |
| Branch protection partial migration | Issue continues; actor-specific settings documented in `BRANCH_PROTECTION_MANUAL` env var and reported in comment |
| Rulesets API denied (403) | Issue continues; warning posted that rulesets may need manual re-creation |
| GHAS migration partial failure | Issue continues; manual steps documented in `GHAS_MANUAL` env var and reported in comment |
| Secrets not readable | Secret names listed for manual re-creation; workflow continues |
| Verification failure (branch/tag/SHA mismatch) | Cutover is skipped; issue remains open for investigation |
| Archive source failure on GHES | Warning logged; issue still closes successfully |

---

## 9. Implementation Checklist

### Phase 1: Foundation

- [x] Create issue template (`ghec-migration-request.yml`) with all form fields
- [x] Add input validation (regex for repo naming, required fields)
- [x] Add confirmation checkboxes for user acknowledgment
- [x] Document prerequisites in the template header

### Phase 2: Workflow — Validation & Approval

- [x] Implement issue body parsing with `actions/github-script` (Job 1)
- [x] Implement field-level validation (empty checks, naming convention)
- [x] Implement source repo existence & archived check
- [x] Implement target org existence check (with user fallback)
- [x] Implement target repo existence check (must already exist)
- [x] Post detailed validation results as issue comment
- [x] Add `migration-approval` environment gate (Job 2)

### Phase 3: Workflow — Migration Execution

- [x] Implement pre-migration state recording (branches, tags, HEAD SHA) (Job 3)
- [x] Implement GEI CLI installation and migration execution (Job 4)
- [x] Capture and post GEI output to issue

### Phase 4: Workflow — Post-Migration & Verification

- [x] Implement admin collaborator assignment (Job 5)
- [x] Implement team access mapping parser and applicator
- [x] Implement full branch protection rules migration from source (with fallback probing)
- [x] Implement rulesets migration (repo-level + org-level fallback)
- [x] Implement Actions permissions migration (policy, selected actions, workflow permissions)
- [x] Implement environments migration (environments + variables)
- [x] Implement repository-level Actions variables migration
- [x] Implement secret names listing (Actions, Dependabot, environment secrets)
- [x] Implement GHAS permissions migration (7 sub-steps)
- [x] Implement migration integrity verification (Job 6)

### Phase 5: Workflow — Cutover & Closure

- [x] Implement source repo archival on GitHub.com (Job 7)
- [x] Implement issue closure with completion summary (Job 8)
- [x] Implement label lifecycle management

### Phase 6: Operational Readiness

- [ ] Create `migration-approval` environment with required reviewers
- [ ] Generate and store `GH_SOURCE_PAT` with correct scopes
- [ ] Generate and store `GH_TARGET_PAT` with correct GHEC scopes
- [ ] Run end-to-end test with a non-critical repository
- [ ] Document runbook for manual intervention scenarios
- [ ] Establish monitoring/alerting for failed migration workflows

---

## 10. Testing Plan

| Test Case | Input | Expected Outcome |
|-----------|-------|-----------------|
| Happy path | Valid source/target, all fields populated, target repo exists | Full migration completes, issue closed with `completed` label |
| Missing required field | Empty source org | Validation fails, error posted to issue |
| Invalid repo name | `MyRepo_123` | Validation fails with naming convention error |
| Source repo archived | Archived source repo | Validation fails with "cannot migrate archived repo" |
| Target repo does not exist | Non-existent target repo name | Validation fails with "does not exist — please create the target repository first" |
| Approval rejected | Reviewer denies approval | Workflow stops at approval gate |
| GEI failure | Network issue during migration | Migration job fails, error posted to issue |
| Partial branch protection migration | Actor-specific settings on source | Branch protection migrated partially; manual items listed in comment |
| Rulesets API denied | Source org on free plan (HTTP 403) | Warning posted; rulesets migration skipped |
| Partial GHAS migration | GHAS not licensed on target | GHAS steps report partial, list manual actions |
| Verification mismatch | Tag count differs | Cutover is skipped, issue remains open for investigation |
| Archive source disabled | Checkbox unchecked | Cutover skips archival, issue still closes |

---

## 11. Security Considerations

1. **PAT rotation**: Both `GH_SOURCE_PAT` and `GH_TARGET_PAT` should be rotated periodically
2. **Least privilege**: PATs should have the minimum scopes required
3. **Approval gate**: Prevents unauthorized migrations via the `migration-approval` environment
4. **No secrets in logs**: All `curl` responses are written to temp files, not echoed directly
5. **Branch protection**: Migrated from source to target to preserve existing rules
6. **GHAS parity**: Security settings from source are replicated to target where possible
7. **Secrets handling**: Secret values are never exposed — only names are listed for manual re-creation

---

## 12. Known Limitations

| Limitation | Impact | Mitigation |
|------------|--------|------------|
| Branch/tag pagination | Repos with >100 branches/tags may show incorrect counts in verification | Use paginated API calls or GitHub CLI |
| GEI does not migrate GitHub Actions secrets | Secrets must be re-added manually | Secret names listed in post-migration comment for reference |
| Actor-specific branch protection settings | Push restrictions, dismissal restrictions, bypass allowances, lock branch, required deployments cannot be migrated (IDs differ between orgs) | Non-migratable items reported in issue comment for manual re-configuration |
| Rulesets API on free plans | Repo-level rulesets API returns 403 for private repos on free plans | Workflow falls back to org-level rulesets; if both fail, reports in comment |
| Environment secrets not readable | Environment secret values cannot be read via API | Environment secret names listed in post-migration comment |
| Org-level security managers | Cannot be migrated programmatically | Reported in issue comment for manual action |
| Webhooks not migrated | Webhooks must be reconfigured manually | Document in runbook |
| GitHub Pages configuration | Not migrated by GEI | Manual reconfiguration needed |
| Deploy keys | Not migrated by GEI | Manual reconfiguration needed |
| Migration manifest | Manifest update step is currently commented out | Enable when manifest tracking is needed |
