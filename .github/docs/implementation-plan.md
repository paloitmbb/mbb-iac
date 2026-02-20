# MBB GHEC Migration — Implementation Plan

## 1. Overview

This document describes the implementation plan for the **GitHub Enterprise Cloud (GHEC) repository migration** solution. The system is driven by a GitHub Issues form and an automated GitHub Actions workflow that uses the **GitHub Enterprise Importer (GEI) CLI** to perform the migration end-to-end between GitHub.com organizations/accounts.

> **⚠️ IMPORTANT UPDATE (Current Implementation):**
>
> The implementation has been updated from the original GHES → GHEC plan:
>
> - **GitHub.com → GitHub.com migration** — source and target are both on GitHub.com (no GHES URL required)
> - **Target repo must already exist** — the workflow validates that the target repository exists before proceeding (does not create a new repo)
> - **Pre-migration runs before approval** — source repo stats and security alerts are recorded before the approval gate, giving reviewers full context
> - **Comprehensive source repo stats** — pre-migration captures repo name, archived status, size, branches, tags, protected branches, PR count, issue count, release count, and HEAD SHA
> - **Security alerts scanning** — Dependabot, Code Scanning, and Secret Scanning alerts are scanned and reported before migration
> - **Full branch protection migration** — branch protection rules are migrated from source with fallback probing, not just default branch protection
> - **Rulesets migration** — repository and org-level rulesets are migrated (repo-level first, org-level fallback)
> - **Actions permissions migration** — permissions policy, selected actions, and workflow permissions are migrated
> - **Environments migration** — environments and their variables are migrated from source
> - **Repository-level Actions variables migration** — repo-level Actions variables are migrated
> - **Secret names listing** — secret names are listed for manual re-creation (values cannot be read via API)
> - **GHAS migration expanded** — includes code scanning default setup, secret scanning non-provider patterns, validity checks
> - **Validation steps consolidated** — Parse + Display merged, validation steps consolidated, Post results + Summary merged into single step

### Components

| Component | Path | Purpose |
|-----------|------|---------|
| Issue Template | `.github/ISSUE_TEMPLATE/ghec-migration-request.yml` | Self-service form for users to request a repository migration |
| Workflow | `.github/workflows/issue-ghec-migration.yml` | 8-job pipeline that validates, records state, approves, migrates, configures, verifies, and closes the request |

---

## 2. Prerequisites

Before the solution can be used, the following must be in place:

| # | Prerequisite | Details |
|---|-------------|---------|
| 1 | **GH_SOURCE_PAT** secret | A Personal Access Token with **read** access to the source GitHub.com repository (repo, admin:org scopes) |
| 2 | **GH_TARGET_PAT** secret | A Personal Access Token with **write/admin** access to the target GitHub.com organization (repo, admin:org, workflow scopes) |
| 3 | **Target org exists on GitHub.com** | The target GitHub.com organization must already be created |
| 4 | **Target repo must already exist** | The target repository must be pre-created on GitHub.com before requesting migration |
| 5 | **`migration-approval` environment** | A GitHub environment with required reviewers configured for the approval gate |

---

## 3. Issue Template — `ghec-migration-request.yml`

### 3.1 Form Structure

The issue template collects all information needed to execute a migration:

| Section | Field | Type | Required | Validation |
|---------|-------|------|----------|------------|
| **Source (GitHub.com)** | Source Organization | `input` | Yes | — |
| | Source Repository Name | `input` | Yes | — |
| **Target (GitHub.com)** | Target Organization | `input` | Yes | Must exist on GitHub.com |
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

## 4. Workflow — `issue-ghec-migration.yml`

### 4.1 Trigger

```yaml
on:
  issues:
    types: [opened]
```

The workflow triggers when an issue is opened and filters by title prefix `[GHEC Migration]` (set automatically by the issue template).

### 4.2 Job Pipeline

The workflow consists of **8 sequential jobs** with dependency gates:

```
┌──────────┐    ┌───────────────┐    ┌──────────┐    ┌─────────┐
│ validate │───►│ pre-migration │───►│ approval │───►│ migrate │
└──────────┘    └───────────────┘    └──────────┘    └────┬────┘
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

**Job dependency chain:**

| Job | Depends On |
|-----|-----------|
| `validate` | — |
| `pre-migration` | `validate` |
| `approval` | `validate`, `pre-migration` |
| `migrate` | `validate`, `pre-migration` |
| `post-migration` | `validate`, `pre-migration`, `migrate` |
| `verify` | `validate`, `pre-migration`, `migrate`, `post-migration` |
| `cutover` | `validate`, `pre-migration`, `verify` |
| `close-issue` | `validate`, `verify`, `cutover` |

---

### 4.3 Job 1: Validate (`validate`)

**Purpose:** Parse the issue body, extract all fields, and validate them against the source and target on GitHub.com.

| # | Step | Description | Implementation Detail |
|---|------|-------------|----------------------|
| 1 | Checkout | Clone the repository | `actions/checkout@v4` |
| 2 | Parse Issue Form | Extract fields from issue body using regex, log all parsed values for debugging | `actions/github-script@v7` with custom JS parsing functions (`extractField`, `extractTextarea`, `extractCheckboxes`) |
| 3 | Validate required fields | Check all mandatory fields are non-empty (consolidated into single step) | Shell script with error accumulation |
| 4 | Validate source and target repos | Validate source repo exists, target org exists, target repo exists | `GET /repos/{org}/{repo}` with `GH_SOURCE_PAT` and `GH_TARGET_PAT` — also checks archived status |
| 5 | Post validation results and summary | Post detailed comment to issue, add labels, write GitHub Actions job summary | `actions/github-script@v7` — adds labels (`validation-passed` or `validation-failed`), writes `core.summary`, calls `core.setFailed()` on failure |
| 6 | Label as in-progress | Add `in-progress` label to issue | `gh issue edit --add-label` |

**Outputs propagated to downstream jobs:**

- `source_organization`, `source_repo`, `target_organization`, `target_repo`
- `target_visibility`, `migration_options`, `admins`, `team_mappings`, `justification`
- `issue_number`

---

### 4.4 Job 2: Pre-Migration Setup (`pre-migration`)

**Purpose:** Record the source repository's comprehensive state (stats and security alerts) before the approval gate, giving reviewers full context.

**Depends on:** `validate`

| # | Step | Description | API Endpoint |
|---|------|-------------|---------------------|
| 1 | Parse migration options | Extract `archive_source` flag from checkboxes | String match on `"Archive source repository"` |
| 2 | Record source repository state | Capture comprehensive repo stats: repo name, archived status, size (human-readable), branch count (paginated), tag count (paginated), HEAD SHA, default branch, protected branch count (paginated), PR count (all states via search API), issue count (all states via search API), release count | `GET /repos/{org}/{repo}`, `/branches`, `/tags`, `/branches/{default}`, `/branches?protected=true`, `/search/issues?q=type:pr`, `/search/issues?q=type:issue`, `/releases` |
| 3 | Scan source repository security alerts | Scan for open Dependabot alerts (description + severity), Code Scanning alerts (description + severity), Secret Scanning alerts (type + validity) | `GET /repos/{org}/{repo}/dependabot/alerts?state=open`, `/code-scanning/alerts?state=open`, `/secret-scanning/alerts?state=open` |
| 4 | Comment pre-migration state | Post comprehensive metrics table + security alerts tables to issue | `gh issue comment` (GitHub CLI) |

**Outputs:**

| Output | Description |
|--------|-------------|
| `source_branches` | Total branch count (paginated) |
| `source_tags` | Total tag count (paginated) |
| `source_head_sha` | HEAD SHA of default branch |
| `source_default_branch` | Default branch name |
| `source_protected_branches` | Protected branch count |
| `source_pr_count` | Total PR count (all states) |
| `source_issue_count` | Total issue count (all states) |
| `source_release_count` | Total release count |
| `source_repo_size` | Repository size (human-readable KB/MB/GB) |
| `source_is_archived` | Whether source repo is archived |
| `archive_source` | Whether to archive source after migration |

---

### 4.5 Job 3: Approval Gate (`approval`)

**Purpose:** Pause the workflow and require manual approval before proceeding with the migration. Reviewers can see the pre-migration stats and security alerts posted in the issue before approving.

**Depends on:** `validate`, `pre-migration`

| # | Step | Description |
|---|------|-------------|
| 1 | Comment approval requested | Post comment with migration summary asking for review |
| 2 | Approval granted | Log approval confirmation |
| 3 | Comment approval granted | Post confirmation comment |

**Implementation Requirements:**

- Create a GitHub environment named `migration-approval`
- Add required reviewers (team leads, admins) to the environment
- Optionally configure a wait timer

---

### 4.6 Job 4: Execute GEI Migration (`migrate`)

**Purpose:** Run the GitHub Enterprise Importer CLI to migrate the repository.

**Depends on:** `validate`, `pre-migration`

| # | Step | Description |
|---|------|-------------|
| 1 | Install GEI CLI | `gh extension install github/gh-gei` |
| 2 | Run GEI migration | Execute `gh gei migrate-repo` with all parameters |
| 3 | Comment migration result | Post success/failure with GEI output |

**GEI Command:**

```bash
gh gei migrate-repo \
  --github-source-org "$SRC_ORG" \
  --source-repo "$SRC_REPO" \
  --github-target-org "$TGT_ORG" \
  --target-repo "$TGT_REPO" \
  --target-repo-visibility "$VISIBILITY" \
  --verbose
```

**Environment Variables:**

| Variable | Source |
|----------|--------|
| `GH_SOURCE_PAT` | `secrets.GH_SOURCE_PAT` |
| `GH_PAT` | `secrets.GH_TARGET_PAT` |

---

### 4.7 Job 5: Post-Migration Setup (`post-migration`)

**Purpose:** Configure the target repository with proper access, protection rules, security settings, environments, variables, and report secrets requiring manual re-creation.

| # | Step | Description | API Used |
|---|------|-------------|----------|
| 1 | Wait 15s | Let GitHub.com finalize the import | `sleep 15` |
| 2 | Add admin collaborators | Iterate comma-separated admin list, add each as admin | `PUT /repos/{org}/{repo}/collaborators/{user}` |
| 3 | Apply team access mappings | Parse `source → target : permission` format, apply each | `PUT /orgs/{org}/teams/{team}/repos/{org}/{repo}` |
| 4 | Migrate branch protection rules | Full migration from source: list protected branches (with fallback probe for free-plan orgs), extract migratable settings (status checks, PR reviews, enforce admins, linear history, force pushes, deletions, block creations, conversation resolution, fork syncing, required signatures), skip actor-specific settings (push restrictions, dismissal restrictions, bypass allowances, lock branch, required deployments), apply to target. Non-migratable settings tracked in `BRANCH_PROTECTION_MANUAL` env var for issue comment | `GET/PUT /repos/{org}/{repo}/branches/{branch}/protection` |
| 5 | Migrate rulesets | Repo-level first (`GET /repos/{org}/{repo}/rulesets`), org-level fallback (`GET /orgs/{org}/rulesets` filtered by repo). Cleans org-specific fields before creating on target | `POST /repos/{org}/{repo}/rulesets` |
| 6 | Migrate Actions permissions | Permissions policy, selected actions (if applicable), default workflow permissions | `GET/PUT /repos/{org}/{repo}/actions/permissions`, `/actions/permissions/selected-actions`, `/actions/permissions/workflow` |
| 7 | Migrate environments | Environments and their variables (secrets cannot be read) | `GET/PUT /repos/{org}/{repo}/environments/{name}`, `/environments/{name}/variables` |
| 8 | Migrate repo-level Actions variables | Paginated variable migration from source to target | `GET/POST /repos/{org}/{repo}/actions/variables` |
| 9 | List repo-level secret names | List Actions secrets, Dependabot secrets, and environment secrets (names only — values are unreadable via API) | `GET /repos/{org}/{repo}/actions/secrets`, `/dependabot/secrets`, `/environments/{name}/secrets` |
| 10 | Migrate GHAS permissions | Multi-step security migration (see §4.7.1) | Multiple GitHub.com API calls |
| 11 | Comment results | Post comprehensive summary with manual action items | `gh issue comment` (GitHub CLI) |

#### 4.7.1 Advanced Security (GHAS) Migration Sub-steps

| Sub-step | Action | Source API | Target API |
|----------|--------|------------|------------|
| 1 | Read source GHAS settings | `GET /repos/{org}/{repo}` → `security_and_analysis` | — |
| 2 | Enable Advanced Security on target (if enabled on source) | — | `PATCH /repos/{org}/{repo}` with `advanced_security.status: "enabled"` |
| 3 | Apply Secret Scanning settings | — | `PATCH /repos/{org}/{repo}` with `secret_scanning`, `push_protection`, `validity_checks`, `non_provider_patterns` |
| 4 | Enable Dependabot | — | `PUT /repos/{org}/{repo}/vulnerability-alerts` + `PATCH` with `dependabot_security_updates` |
| 5 | Migrate Code Scanning default setup | `GET /repos/{org}/{repo}/code-scanning/default-setup` | `PATCH /repos/{org}/{repo}/code-scanning/default-setup` |
| 6 | Check Security Manager teams | `GET /orgs/{org}/security-managers` | Informational only (org-level, manual re-config required) |

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

**Purpose:** Archive the source repo (if requested) after successful verification.

| # | Step | Condition | Description |
|---|------|-----------|-------------|
| 1 | Checkout | Always | Clone repo for potential manifest updates |
| 2 | Archive source on GitHub.com | `archive_source == 'true'` | `PATCH https://api.github.com/repos/{org}/{repo}` with `{"archived": true, "description": "[MIGRATED]..."}` |

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
| `GH_SOURCE_PAT` | Source GitHub.com | `repo` (read), `admin:org` (read) on the source organization |
| `GH_TARGET_PAT` | Target GitHub.com (GHEC) | `repo`, `admin:org`, `workflow`, `delete_repo` on the target GHEC org |

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
| `ghec-migration-request` | — | On issue creation (via template) | Never |
| `validation-passed` | — | After successful validation | Never |
| `validation-failed` | — | After failed validation | Never |
| `in-progress` | `#FBCA04` | After validation passes | On issue close |
| `completed` | — | On successful migration | Never |

---

## 8. Error Handling Strategy

| Scenario | Behavior |
|----------|----------|
| Missing required fields | Issue comment with specific errors; workflow exits |
| Source repo not found / archived | Issue comment explaining the problem; workflow exits |
| Target repo does not exist | Issue comment asking user to create the target repo first; workflow exits |
| GEI migration failure | Issue comment with GEI output; workflow exits |
| Branch protection partial migration | Issue continues; actor-specific settings documented in `BRANCH_PROTECTION_MANUAL` env var and reported in comment |
| Rulesets API denied (403) | Issue continues; warning posted that rulesets may need manual re-creation |
| GHAS migration partial failure | Issue continues; manual steps documented in `GHAS_MANUAL` env var and reported in comment |
| Secrets not readable | Secret names listed for manual re-creation; workflow continues |
| Security alerts API denied | Warning logged; security alerts section omitted from comment (404 for Code Scanning/Secret Scanning is silently skipped as it means the feature is not enabled) |
| Verification failure (branch/tag/SHA mismatch) | Cutover is skipped; issue remains open for investigation |
| Archive source failure | Warning logged; issue still closes successfully |

---

## 9. Implementation Checklist

### Phase 1: Foundation

- [x] Create issue template (`ghec-migration-request.yml`) with all form fields
- [x] Add input validation (regex for repo naming, required fields)
- [x] Add confirmation checkboxes for user acknowledgment
- [x] Document prerequisites in the template header

### Phase 2: Workflow — Validation & Approval

- [x] Implement issue body parsing with `actions/github-script` (Job 1) — Parse + Display values merged into single step
- [x] Implement field-level validation (empty checks, naming convention) — consolidated into single step
- [x] Implement source repo existence & archived check
- [x] Implement target org existence check (with user fallback)
- [x] Implement target repo existence check (must already exist)
- [x] Post detailed validation results, labels, and job summary as single consolidated step
- [x] Add `migration-approval` environment gate (Job 3) — runs after pre-migration so reviewers have full context

### Phase 3: Workflow — Pre-Migration & Migration Execution

- [x] Implement pre-migration state recording (repo name, archived, size, branches, tags, HEAD SHA, protected branches, PR count, issue count, releases — all with pagination) (Job 2)
- [x] Implement security alerts scanning (Dependabot, Code Scanning, Secret Scanning) with alert tables in issue comment (Job 2)
- [x] Implement pre-migration comment with comprehensive stats table + security alerts (Job 2)
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
| Source repo archived | Archived source repo | Validation flags archived status; pre-migration records `is_archived=true` |
| Target repo does not exist | Non-existent target repo name | Validation fails with "does not exist — please create the target repository first" |
| Source repo with security alerts | Repo with Dependabot/Code Scanning/Secret Scanning alerts | Pre-migration comment includes alert tables with descriptions and severities |
| Source repo without security features | Repo without GHAS enabled | Security alerts step gracefully handles 404 responses (features not enabled) |
| Large repo with many branches/tags | Repo with >100 branches and tags | Paginated branch/tag counting captures accurate totals |
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
| GEI does not migrate GitHub Actions secrets | Secrets must be re-added manually | Secret names listed in post-migration comment for reference |
| Actor-specific branch protection settings | Push restrictions, dismissal restrictions, bypass allowances, lock branch, required deployments cannot be migrated (IDs differ between orgs) | Non-migratable items reported in issue comment for manual re-configuration |
| Rulesets API on free plans | Repo-level rulesets API returns 403 for private repos on free plans | Workflow falls back to org-level rulesets; if both fail, reports in comment |
| Environment secrets not readable | Environment secret values cannot be read via API | Environment secret names listed in post-migration comment |
| Org-level security managers | Cannot be migrated programmatically | Reported in issue comment for manual action |
| Webhooks not migrated | Webhooks must be reconfigured manually | Document in runbook |
| GitHub Pages configuration | Not migrated by GEI | Manual reconfiguration needed |
| Deploy keys | Not migrated by GEI | Manual reconfiguration needed |
| Migration manifest | Manifest update step is currently commented out | Enable when manifest tracking is needed |
| Security alerts descriptions truncated | Dependabot/Code Scanning alert descriptions are truncated to 80 characters in issue comment tables | Full details available in source repo security tab |
| Search API rate limits | PR and issue counts use the search API which has stricter rate limits (30 req/min) | Only 2 search calls per migration; unlikely to hit limits |
