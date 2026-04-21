# State Sharding via Repository Topics — Implementation Plan

**Date:** 19 April 2026
**Status:** ✅ Implementation Complete
**Summary Reference:** [04-IMPLEMENTATION_SUMMARY.md](./04-IMPLEMENTATION_SUMMARY.md)

---

## Problem

All repositories, teams, security configs, and the organization are managed in a **single Terraform state** (`github.terraform.tfstate`). As the organization scales to thousands of repos, a single `terraform plan`/`apply` becomes prohibitively slow because Terraform must refresh every resource in the state on every run.

Additionally, when many PRs update `data/repositories.yaml` concurrently, merge conflicts are frequent and painful.

---

## Core Idea

Use a **dedicated topic** on each repository (e.g., `state-group-001`, `state-group-002`, …) to **bind repositories to a specific state shard**. Each shard manages at most 50 repositories plus the team-repo bindings associated with those repositories. A thin "global" state manages org-level settings and team definitions (without repo bindings).

Separately, repository YAML data files are **split across multiple files** using a round-robin strategy. YAML file splitting is **completely independent** of state-group shard assignments — a repo's file location has no bearing on which Terraform state manages it.

---

## Architecture: Three Terraform Root Configs

```
mbb-iac/
├── main.tf                         # EXISTING monolithic config (UNTOUCHED)
├── variables.tf                    #   ↳ Preserves existing tf-state
├── outputs.tf                      #   ↳ and all managed resources
├── versions.tf                     #
│
├── global/                         # NEW — Shard 0: org settings + team shells
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
│
├── shards/                         # NEW — Template for each repo shard
│   ├── main.tf                     #   Filters repos by state-group topic
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
│
├── modules/                        # UNCHANGED — Shared modules
│   ├── github-organization/
│   ├── github-repository/
│   ├── github-security/
│   └── github-team/
│
├── data/
│   ├── repositories.yaml           # Primary repo file (split files: -002, -003, ...)
│   ├── teams.yaml
│   └── defaults.yaml
│
├── environments/
│   ├── dev/
│   │   ├── backend.tfvars
│   │   └── terraform.tfvars
│   └── production/
│       └── ...
│
└── scripts/
    ├── assign-state-groups.sh      # Auto-assign state-group topics
    ├── validate-state-groups.sh    # CI guardrail: validate topic assignments
    ├── round-robin-repo-file.sh    # Pick target YAML file for new repo
    ├── split-repositories-yaml.sh  # Retroactive rebalancing of large files
    ├── shard-init.sh               # Init a specific shard
    ├── shard-plan.sh               # Plan a specific shard
    ├── shard-apply.sh              # Apply a specific shard
    ├── shard-plan-all.sh           # Discover all shards, plan in parallel
    ├── global-init.sh              # Init the global state
    ├── global-plan.sh              # Plan the global state
    ├── global-apply.sh             # Apply the global state
    └── migrate-to-shards.sh        # Generate state mv commands (review-only)
```

---

## Design Decisions

### 1. Existing State is Preserved

The root `main.tf`, `variables.tf`, `outputs.tf`, and `versions.tf` are **never modified**. The monolithic state file (`github.terraform.tfstate`) and all resources it manages remain untouched. The `global/` and `shards/` directories are purely additive — they create **new, independent** state files.

Migration from the monolith to shards is a separate, **opt-in** manual operation using `scripts/migrate-to-shards.sh`, which only generates `terraform state mv` commands for human review and never auto-executes.

### 2. YAML File Splitting is Independent of State Shards

A repository's location in `data/repositories.yaml` vs `data/repositories-002.yaml` has **no bearing** on which Terraform state manages it. State binding is determined solely by the `state-group-NNN` topic on each repo.

This means:
- YAML files can be split/merged freely without affecting state.
- Merge conflicts are reduced because concurrent PRs often touch different files.
- The round-robin balancer automatically distributes new repos across files.

### 3. Round-Robin File Balancing

New repos are distributed across YAML files using a **round-robin** strategy:
1. If the number of YAML files is **less than** the target count (env var `REPO_DATA_FILE_COUNT`, default 50): create a new file.
2. If the number of files **meets or exceeds** the target: append to the file with the fewest repos.

This ensures even distribution and minimizes the chance that two concurrent PRs modify the same file.

### 4. Team–Repo Binding Strategy

Teams are defined in the **global state** (`global/main.tf`). Team-to-repository bindings are managed in **each shard** using `data "github_team" "lookup"` to resolve team slugs to IDs at plan time. This avoids cross-state `terraform_remote_state` dependencies and lets shards run fully independently.

---

## Step-by-Step Plan

### Step 1: Topic-Based State Group Assignment

Each repository must carry exactly one topic matching `state-group-NNN`. The `scripts/assign-state-groups.sh` auto-assigns topics to unassigned repos across **all** `data/repositories*.yaml` files.

**Rules:**
- A repo's `state-group-NNN` topic is **immutable** once assigned.
- The script only **adds** topics; never moves repos between groups.
- Archived repos keep their topic.

### Step 2: Global State (Shard 0)

**Location:** `global/`
**State key:** `github-global.terraform.tfstate`

Manages:
- `module.github_organization` — org settings, GHAS defaults.
- `module.github_teams` — team definitions (no `github_team_repository` bindings).

### Step 3: Repository Shards

**Location:** `shards/` (parameterized by `var.shard_id`)
**State key:** `github-shard-<NNN>.terraform.tfstate`

Each shard:
1. Reads all `data/repositories*.yaml` files and filters to repos with `state-group-<shard_id>`.
2. Filters `data/teams.yaml` bindings to repos in this shard.
3. Instantiates repo modules, security modules, and team-repo binding resources.

### Step 4: CI/CD Pipeline

**New workflows** (existing workflows are NOT modified):
- `terraform-sharded-ci.yml` — PR validation with dynamic shard detection and matrix strategy.
- `terraform-sharded-apply.yml` — Apply with parallel shard matrix, concurrency controls per shard.

**Updated workflows** (additive changes only):
- `repository-create.yml` — Uses round-robin to select target YAML file.
- `onboard-unmanaged-repos.yml` — Distributes bulk-onboarded repos across files.
- `terraform-apply.yml` — Detects changes across all `data/repositories*.yaml` files.

### Step 5: Migration Path

1. Run `scripts/assign-state-groups.sh` to assign topics to all existing repos.
2. Initialize `global/` and import org + team resources.
3. For each shard, use `scripts/migrate-to-shards.sh` to generate `terraform state mv` commands.
4. Review and execute commands manually.
5. Verify with `terraform plan` in each config.
6. Decommission the old monolithic state.

### Step 6: Guardrails & Validation

- `scripts/validate-state-groups.sh` — CI check: every repo has exactly one `state-group-NNN` topic, no duplicates across files, no shard exceeds 50 repos.
- Shard discovery in `shard-plan-all.sh` detects all shards from YAML.

---

## Summary Table

| Concern | Current | Proposed |
|---|---|---|
| State files | 1 monolith per env | 1 global + N shards (≤50 repos each) per env |
| Plan/apply time | O(all repos) | O(50 repos) per shard, parallelized |
| Repo → state binding | Implicit (all in one) | Explicit via `state-group-NNN` topic |
| Team management | Single state | Teams in global; team-repo bindings in shards |
| CI parallelism | Serial | Matrix strategy, 1 job per shard |
| New repo onboarding | Single YAML file | Round-robin across split YAML files |
| YAML merge conflicts | Frequent | Minimized via file splitting |
| Existing state | — | Fully preserved; migration is opt-in |
| Migration | N/A | `terraform state mv` script (review-only) |
