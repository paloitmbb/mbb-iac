# GHES → GHEC Migration Plan

> **Project:** Maybank GitHub Enterprise Automation
> **Version:** 1.0
> **Last Updated:** 11 February 2026
> **Status:** Planning

---

## 1. Executive Summary

This document outlines the plan for migrating repositories from **GitHub Enterprise Server (GHES)** to **GitHub Enterprise Cloud (GHEC)**. The migration will be automated through GitHub Actions workflows triggered by issue templates, following the same IaC-driven approach used for repository creation and other operations in this project.

### 1.1 Migration Goals

| # | Goal | Priority |
|---|------|----------|
| 1 | Zero data loss — all git history, branches, tags preserved | 🔴 Critical |
| 2 | Minimal downtime — cut-over window < 2 hours per repo | 🔴 Critical |
| 3 | Automated & repeatable — issue-driven, no manual SSH/CLI | 🟡 High |
| 4 | Full audit trail — every migration logged via issues + YAML | 🟡 High |
| 5 | Rollback capability — ability to undo failed migrations | 🟡 High |
| 6 | Post-migration validation — automated verification checks | 🟡 High |
| 7 | Batch migration support — migrate multiple repos in one request | 🟢 Medium |

### 1.2 Migration Tool

**GitHub Enterprise Importer (GEI)** — the officially supported migration tool by GitHub.

```bash
# Install GEI extension
gh extension install github/gh-gei
```

---

## 2. Pre-Migration Assessment

### 2.1 Inventory & Discovery

Before migration begins, a full inventory of GHES repositories must be gathered:

| Data Point | Source | Method |
|------------|--------|--------|
| Total repositories | GHES API | `GET /api/v3/orgs/{org}/repos` |
| Repository sizes | GHES API | `disk_usage` field |
| Active vs archived repos | GHES API | `archived` field |
| Open pull requests | GHES API | `GET /api/v3/repos/{owner}/{repo}/pulls` |
| Branch protection rules | GHES API | `GET /api/v3/repos/{owner}/{repo}/branches/{branch}/protection` |
| Webhooks | GHES API | `GET /api/v3/repos/{owner}/{repo}/hooks` |
| GitHub Actions usage | GHES API | Check `.github/workflows/` existence |
| LFS usage | GHES API | `GET /api/v3/repos/{owner}/{repo}/git/lfs` |
| GHES version | GHES Admin | Must be >= 3.4.1 for GEI support |

### 2.2 Pre-Requisites Checklist

| # | Requirement | Status | Owner |
|---|------------|--------|-------|
| 1 | GHES version >= 3.4.1 | ⬜ Pending | Platform Team |
| 2 | GHEC organization created | ⬜ Pending | Admin |
| 3 | GHES PAT with `repo`, `admin:org` scopes | ⬜ Pending | Admin |
| 4 | GHEC PAT with `repo`, `admin:org`, `workflow` scopes | ⬜ Pending | Admin |
| 5 | GEI CLI installed on runners (`gh gei`) | ⬜ Pending | Platform Team |
| 6 | Network connectivity: Runner → GHES (HTTPS) | ⬜ Pending | Network Team |
| 7 | Network connectivity: Runner → GHEC (HTTPS) | ⬜ Pending | Network Team |
| 8 | Azure Blob Storage for migration archives (optional) | ⬜ Pending | Platform Team |
| 9 | User mapping file (GHES → GHEC usernames) | ⬜ Pending | Admin |
| 10 | Team mapping file (GHES → GHEC team slugs) | ⬜ Pending | Admin |
| 11 | Stakeholder sign-off for migration window | ⬜ Pending | Management |
| 12 | Communication plan for repo owners | ⬜ Pending | PMO |

### 2.3 GHES vs GHEC Compatibility Matrix

| Feature | GHES | GHEC | Migration Notes |
|---------|------|------|-----------------|
| Git repository (code, history) | ✅ | ✅ | Full migration via GEI |
| Pull requests | ✅ | ✅ | Migrated with comments, reviews |
| Issues | ✅ | ✅ | Migrated with labels, milestones |
| Releases | ✅ | ✅ | Migrated with assets |
| Wikis | ✅ | ✅ | Migrated as-is |
| GitHub Actions | ✅ | ✅ | Code migrated; update runner labels & secrets |
| Packages | ✅ | ✅ | Re-publish required |
| GitHub Pages | ✅ | ✅ | Reconfigure custom domains |
| Branch protection | ✅ | ✅ | Re-apply via Terraform or API |
| Rulesets | ⚠️ Limited | ✅ | Create fresh in GHEC |
| Webhooks | ✅ | ✅ | URLs must be updated |
| Deploy keys | ✅ | ✅ | Re-create |
| Secrets & Variables | ✅ | ✅ | Re-create (not migrated) |
| SAML/SSO integration | SAML | SAML/OIDC | Reconfigure IdP |
| IP allow lists | ✅ | ✅ | Update for cloud IPs |
| Audit logs | ✅ | ✅ | GHES logs retained separately |
| Dependabot | ✅ | ✅ | Auto-enabled on GHEC |
| Code scanning | ✅ | ✅ | Re-trigger after migration |
| Secret scanning | ✅ | ✅ | Auto-enabled on GHEC |

---

## 3. Migration Strategy

### 3.1 Migration Waves

Repositories will be migrated in waves, prioritized by criticality and complexity:

| Wave | Criteria | Est. Repos | Timeline |
|------|----------|-----------|----------|
| **Wave 0: Pilot** | Low-risk, small repos (< 100MB), no active PRs | 5–10 | Week 1 |
| **Wave 1: Low Risk** | Inactive repos, internal tools, documentation | 20–50 | Week 2–3 |
| **Wave 2: Medium Risk** | Active repos, standard CI/CD | 30–60 | Week 4–6 |
| **Wave 3: High Risk** | Critical production repos, complex CI/CD, LFS | 10–20 | Week 7–8 |
| **Wave 4: Cleanup** | Remaining repos, archive candidates | Remaining | Week 9–10 |

### 3.2 Migration Approaches

| Approach | When to Use | Tool |
|----------|------------|------|
| **GEI (GitHub Enterprise Importer)** | Default for all repos | `gh gei migrate-repo` |
| **Git Push (manual)** | Fallback for edge cases | `git push --mirror` |
| **Archive Only** | Repos no longer active | Terraform archive module |

### 3.3 Per-Repository Migration Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Per-Repository Migration Flow                            │
│                                                                             │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────┐  ┌───────────────────┐  │
│  │ 1. Pre-     │  │ 2. Freeze    │  │ 3. Export   │  │ 4. Import         │  │
│  │ Validation  │  │ Source Repo  │  │ from GHES  │  │ to GHEC           │  │
│  │             │  │              │  │            │  │                   │  │
│  │ • Repo      │  │ • Set read-  │  │ • gh gei   │  │ • gh gei          │  │
│  │   exists    │  │   only       │  │   generate │  │   migrate-repo    │  │
│  │ • No name   │  │ • Notify     │  │   -script  │  │ • Wait for        │  │
│  │   conflict  │  │   owners     │  │ • Archive  │  │   completion      │  │
│  │ • Size OK   │  │ • Drain PRs  │  │   export   │  │ • Import PRs,     │  │
│  │ • GEI ready │  │              │  │            │  │   issues, etc.    │  │
│  └──────┬──────┘  └──────┬───────┘  └─────┬──────┘  └────────┬──────────┘  │
│         │                │                │                   │             │
│         ▼                ▼                ▼                   ▼             │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────┐  ┌───────────────────┐  │
│  │ 5. Post-    │  │ 6. Re-apply  │  │ 7. Verify  │  │ 8. Cutover        │  │
│  │ Migration   │  │ Settings     │  │ Integrity  │  │ & Cleanup         │  │
│  │ Config      │  │              │  │            │  │                   │  │
│  │             │  │ • Branch     │  │ • Commit   │  │ • Update CI/CD    │  │
│  │ • Secrets   │  │   protection │  │   count    │  │ • Update docs     │  │
│  │ • Variables │  │ • Rulesets   │  │ • Branch   │  │ • Archive GHES    │  │
│  │ • Webhooks  │  │ • CODEOWNERS │  │   count    │  │   source repo     │  │
│  │ • Deploy    │  │ • Team perms │  │ • PR count │  │ • Notify teams    │  │
│  │   keys      │  │ • Collabor.  │  │ • File     │  │ • Update YAML     │  │
│  │             │  │              │  │   hashes   │  │   manifest        │  │
│  └─────────────┘  └──────────────┘  └────────────┘  └───────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Issue Template Design

### 4.1 GHES Migration Request Form

```yaml
name: "GHES → GHEC Migration Request"
description: "Request migration of repository from GHES to GHEC"
title: "[Migration] "
labels: ["ghes-migration-request"]
body:
  - Organization (target GHEC org)
  - GHES Server URL
  - GHES Organization
  - GHES Repository Name
  - Target Repository Name (defaults to source name)
  - Migration Options:
    - ☐ Migrate Pull Requests
    - ☐ Migrate Issues
    - ☐ Migrate Releases
    - ☐ Migrate Wiki
    - ☐ Archive source after migration
    - ☐ Lock source repo during migration
  - Target Visibility (private / internal / public)
  - Justification
```

---

## 5. Workflow Architecture

### 5.1 Issue-Driven Migration Workflow

```
┌──────────────────┐
│  User creates    │
│  GitHub Issue    │
│  "Migration      │
│   Request"       │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  validate        │ ← Check GHES repo exists, target available, GEI ready
│  (Job 1)         │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  pre-migration   │ ← Lock/freeze source repo, notify owners, record state
│  (Job 2)         │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  migrate         │ ← Run `gh gei migrate-repo`, track progress
│  (Job 3)         │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  post-migration  │ ← Re-apply settings, secrets, webhooks, branch protection
│  (Job 4)         │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  verify          │ ← Compare commit counts, branches, PRs, file integrity
│  (Job 5)         │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  cutover         │ ← Archive GHES source, update migration YAML, comment
│  (Job 6)         │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  close-issue     │ ← Label as completed, close issue
│  (Job 7)         │
└──────────────────┘
```

### 5.2 Workflow Jobs Detail

| Job | Steps | Failure Behavior |
|-----|-------|-----------------|
| **validate** | Parse issue, check GHES repo exists, check target not taken, validate PATs | Comment error, close issue |
| **pre-migration** | Set source to read-only (optional), record pre-migration state (commits, branches, PRs) | Unlock source, comment error |
| **migrate** | Run `gh gei migrate-repo` with selected options, poll for completion | Comment error, offer retry |
| **post-migration** | Re-create secrets, variables, webhooks, deploy keys, branch protection via Terraform/API | Comment warnings (non-blocking) |
| **verify** | Compare source vs target: commit count, branch count, PR count, tag count, HEAD SHA | Comment verification report |
| **cutover** | Archive GHES source (if opted), update `data/migration-manifests.yaml`, comment summary | Comment error |
| **close-issue** | Add `completed` label, close issue with migration report | — |

---

## 6. Data Model

### 6.1 Migration Manifest (`data/migration-manifests.yaml`)

```yaml
migrations:
  my-legacy-app:
    source:
      server: "https://ghes.company.com"
      organization: "legacy-org"
      repository: "my-legacy-app"
    target:
      organization: "my-ghec-org"
      repository: "my-legacy-app"
      visibility: "private"
    options:
      migrate_pull_requests: true
      migrate_issues: true
      migrate_releases: true
      migrate_wiki: true
      archive_source: true
      lock_source: true
    status: "completed"            # pending | in-progress | completed | failed | rolled-back
    migration_id: "RM_abc123"      # GEI migration ID
    started_at: "2026-02-15T10:00:00Z"
    completed_at: "2026-02-15T10:45:00Z"
    issue_number: 42
    verification:
      source_commits: 1523
      target_commits: 1523
      source_branches: 8
      target_branches: 8
      source_prs: 234
      target_prs: 234
      source_tags: 15
      target_tags: 15
      head_sha_match: true
```

---

## 7. GEI Commands Reference

### 7.1 Generate Migration Script (Dry Run)

```bash
gh gei generate-script \
  --github-source-org <ghes-org> \
  --github-target-org <ghec-org> \
  --ghes-api-url https://ghes.company.com/api/v3 \
  --output migrate.ps1
```

### 7.2 Migrate Single Repository

```bash
gh gei migrate-repo \
  --github-source-org <ghes-org> \
  --source-repo <repo-name> \
  --github-target-org <ghec-org> \
  --target-repo <repo-name> \
  --ghes-api-url https://ghes.company.com/api/v3 \
  --target-repo-visibility private \
  --verbose
```

### 7.3 Check Migration Status

```bash
gh gei wait-for-migration \
  --migration-id <migration-id>
```

### 7.4 Environment Variables for GEI

```bash
export GH_SOURCE_PAT=<ghes-pat>     # PAT for GHES (source)
export GH_PAT=<ghec-pat>            # PAT for GHEC (target)
```

---

## 8. Verification Checks

### 8.1 Automated Post-Migration Verification

| Check | Method | Pass Criteria |
|-------|--------|---------------|
| Commit count | Compare API `GET /repos/.../commits?per_page=1` Link header | Source == Target |
| Branch count | Compare `GET /repos/.../branches` | Source == Target |
| Tag count | Compare `GET /repos/.../tags` | Source == Target |
| Default branch | Check `GET /repos/.../` `.default_branch` | `main` (or matches source) |
| HEAD SHA | Compare default branch HEAD commit SHA | Source == Target |
| PR count (open) | Compare `GET /repos/.../pulls?state=open` | Source == Target |
| PR count (closed) | Compare `GET /repos/.../pulls?state=closed` | Source == Target |
| Issue count | Compare `GET /repos/.../issues` | Source == Target |
| Release count | Compare `GET /repos/.../releases` | Source == Target |
| LFS objects | Compare LFS pointer files | All present |
| File tree hash | Compare `GET /repos/.../git/trees/HEAD` | SHA matches |

### 8.2 Manual Verification Checklist

| # | Check | Owner |
|---|-------|-------|
| 1 | Clone target repo and verify build succeeds | Dev Team |
| 2 | CI/CD pipeline runs successfully | Dev Team |
| 3 | All team members can access the new repo | Team Lead |
| 4 | Branch protection rules are active | Platform Team |
| 5 | Webhooks are functional | Dev Team |
| 6 | GitHub Actions secrets are configured | Platform Team |
| 7 | Dependabot / code scanning active | Security Team |

---

## 9. Risk Matrix

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Large repos (> 10GB) fail migration | Medium | High | Use Azure Blob intermediate storage, split LFS |
| Network timeout during export | Medium | Medium | Retry mechanism in workflow, resume support |
| User mapping mismatches | High | Medium | Pre-create user mapping file, dry-run first |
| Active PRs lost during freeze window | Low | High | Notify teams 48h before, drain PRs first |
| Secrets not re-created | Medium | High | Maintain secrets inventory, use Vault integration |
| Webhooks pointing to wrong URLs | High | Medium | Generate webhook migration report, update DNS |
| Runner can't reach GHES | Low | Critical | Test connectivity before migration wave |
| GEI version incompatibility | Low | Medium | Pin GEI version, test on pilot repos first |
| State file corruption during migration | Low | High | State backups before each migration |
| Team slug differences GHES vs GHEC | Medium | Medium | Team mapping file, validate before migration |

---

## 10. Rollback Plan

### 10.1 During Migration (Pre-Cutover)

If migration fails before cutover:

1. **Delete** the partially migrated repo in GHEC
2. **Unlock** the source repo in GHES (remove read-only)
3. **Update** `migration-manifests.yaml` with status `failed`
4. **Comment** on issue with failure details
5. **Keep** issue open for retry

### 10.2 After Cutover

If issues are discovered after cutover:

1. **Un-archive** the GHES source repo
2. **Re-enable** write access on GHES
3. **Notify** teams to switch back to GHES remote
4. **Investigate** and fix the root cause
5. **Re-attempt** migration

### 10.3 Point of No Return

Migration is considered permanent after:
- ✅ All verification checks pass
- ✅ Teams confirm GHEC repo is functional
- ✅ CI/CD pipelines run on GHEC
- ✅ 48-hour bake period with no issues
- ✅ GHES source is archived

---

## 11. Communication Plan

### 11.1 Timeline

| When | What | Audience |
|------|------|----------|
| T-2 weeks | Migration announcement, timeline published | All developers |
| T-1 week | Detailed schedule per repo, team assignments | Repo owners |
| T-48 hours | Reminder: freeze window approaching | Affected teams |
| T-4 hours | Final reminder, merge/close open PRs | Affected teams |
| T-0 | Migration begins, status updates on issue | All stakeholders |
| T+1 hour | Migration complete, verification started | Affected teams |
| T+2 hours | Cutover complete, new remote URLs shared | Affected teams |
| T+48 hours | Bake period complete, GHES archived | All developers |
| T+1 week | Migration retrospective | Platform Team |

### 11.2 Notification Template

```
Subject: [GitHub Migration] Repository "{repo_name}" migrating from GHES → GHEC

Your repository "{repo_name}" is scheduled for migration.

📅 Date: {date}
⏰ Freeze Window: {start_time} - {end_time}
📍 New URL: https://github.com/{ghec_org}/{repo_name}

Action Required Before Migration:
1. Merge or close all open PRs
2. Push any local branches you want preserved
3. Update any bookmarks/links after migration

Track Progress: {issue_url}
```

---

## 12. Token & Permissions Requirements

### 12.1 Required Personal Access Tokens

| Token | Scope | Used For | Secret Name |
|-------|-------|----------|-------------|
| **GHES PAT** | `repo`, `admin:org`, `read:packages` | Export from GHES | `GHES_PAT_TOKEN` |
| **GHEC PAT** | `repo`, `admin:org`, `workflow`, `delete_repo` | Import to GHEC | `GH_PAT_TOKEN` |

### 12.2 Required GitHub App Permissions (Alternative)

| Permission | Access | Resource |
|------------|--------|----------|
| Repository | Admin | Source & Target repos |
| Organization | Admin | Source & Target orgs |
| Pull Requests | Read/Write | Migration metadata |
| Issues | Read/Write | Migration tracking |

---

## 13. Execution Timeline

### Phase 1: Preparation (Week 1–2)

| Task | Owner | Duration | Dependencies |
|------|-------|----------|-------------|
| Confirm GHES version compatibility | Platform | 1 day | — |
| Create GHEC target organizations | Admin | 1 day | — |
| Generate PATs with required scopes | Admin | 1 day | Orgs created |
| Add PATs as repository secrets | Platform | 1 day | PATs created |
| Install GEI on runners | Platform | 1 day | — |
| Test network connectivity | Network | 2 days | Runner access |
| Build user mapping file | Admin | 3 days | GHES/GHEC user list |
| Build team mapping file | Admin | 2 days | GHES/GHEC team list |
| Create issue template & workflow | Platform | 3 days | — |
| Create migration script | Platform | 3 days | Template done |
| Test on pilot repos (Wave 0) | Platform | 3 days | Script ready |

### Phase 2: Execution (Week 3–8)

| Task | Owner | Duration | Wave |
|------|-------|----------|------|
| Wave 0: Pilot (5–10 repos) | Platform | 3 days | 0 |
| Retrospective & fixes | Platform | 2 days | — |
| Wave 1: Low-risk repos | Platform | 5 days | 1 |
| Wave 2: Medium-risk repos | Platform + Dev | 10 days | 2 |
| Wave 3: High-risk repos | Platform + Dev | 5 days | 3 |
| Wave 4: Cleanup & archive | Platform | 5 days | 4 |

### Phase 3: Post-Migration (Week 9–10)

| Task | Owner | Duration |
|------|-------|----------|
| Final verification of all repos | Platform + QA | 3 days |
| Update all documentation | Platform | 2 days |
| Decommission GHES (decision) | Management | — |
| Migration retrospective | All | 1 day |

---

## 14. Success Criteria

| Metric | Target |
|--------|--------|
| Repositories migrated | 100% of in-scope repos |
| Data integrity | 0 data loss incidents |
| Downtime per repo | < 2 hours |
| CI/CD restored | < 4 hours post-migration |
| Team access restored | < 1 hour post-migration |
| Rollback needed | < 5% of repos |
| Migration automation | > 90% automated (no manual steps) |

---

## 15. Appendix

### A. Useful Commands

```bash
# List all repos in GHES org
gh api --hostname ghes.company.com /orgs/{org}/repos --paginate --jq '.[].full_name'

# Count repos
gh api --hostname ghes.company.com /orgs/{org}/repos --paginate --jq 'length'

# Export repo inventory to CSV
gh api --hostname ghes.company.com /orgs/{org}/repos --paginate \
  --jq '.[] | [.name, .size, .archived, .default_branch, .updated_at] | @csv'

# Check GEI version
gh gei --version

# Dry-run migration
gh gei migrate-repo \
  --github-source-org source-org \
  --source-repo my-repo \
  --github-target-org target-org \
  --target-repo my-repo \
  --ghes-api-url https://ghes.company.com/api/v3 \
  --verbose \
  --dry-run
```

### B. Troubleshooting

| Issue | Solution |
|-------|---------|
| `GEI: 403 Forbidden` | Check PAT scopes, ensure admin access to both orgs |
| `GEI: Repo too large` | Use `--azure-storage-connection-string` for intermediate storage |
| `GEI: Migration timeout` | Increase runner timeout, check GHES load |
| `GEI: User not found` | Update user mapping, check SAML/SSO provisioning |
| `GEI: Archive export failed` | Check GHES disk space, retry |
| `Branch protection not applied` | Re-apply via Terraform after migration |
| `Webhooks returning 404` | Update webhook URLs to point to new endpoints |
| `Actions workflows failing` | Update runner labels, re-create secrets |
