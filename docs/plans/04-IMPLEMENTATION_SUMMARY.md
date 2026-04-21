# State Sharding & YAML Round-Robin — Implementation Summary

**Date:** 19 April 2026
**Status:** ✅ Implementation Complete
**Plan Reference:** [04-STATE_SHARDING_PLAN.md](./04-STATE_SHARDING_PLAN.md)

---

## Overview

Terraform state sharding has been implemented to scale GitHub organization management from a single monolithic state to a 1-global + N-shard architecture. Repositories are bound to shards via `state-group-NNN` topics. Separately, a round-robin YAML file balancing strategy distributes new repository entries across multiple files to minimize merge conflicts.

**Key constraint:** The existing root Terraform config (`main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`) and its state file are **completely untouched**. All new infrastructure is additive.

---

## Files Created

### Terraform Root Configs

| File | Purpose |
|---|---|
| `global/main.tf` | Organization settings + team shells (no repo bindings) |
| `global/variables.tf` | Input variables: organization, teams, ghas_config |
| `global/outputs.tf` | Outputs: org name/ID, team count, team slug→ID map |
| `global/versions.tf` | Provider `~> 6.0`, azurerm backend, key `github-global.terraform.tfstate` |
| `shards/main.tf` | Repos filtered by `state-group-<shard_id>` topic, team-repo bindings via `data.github_team` lookup |
| `shards/variables.tf` | Input variables: shard_id (validated 3-digit), organization_name, repositories, teams |
| `shards/outputs.tf` | Outputs: shard_id, shard_topic, repo count, repo details, binding count |
| `shards/versions.tf` | Provider `~> 6.0`, azurerm backend, key `github-shard-<NNN>.terraform.tfstate` |

### Scripts

| Script | Purpose |
|---|---|
| `scripts/assign-state-groups.sh` | Auto-assign `state-group-NNN` topics to repos without one. Scans all `data/repositories*.yaml` files. Only adds topics; never moves repos. |
| `scripts/validate-state-groups.sh` | CI guardrail: validates every repo has exactly one topic, detects duplicates across files, checks shard sizes (≤50). Exit 1 on failure. |
| `scripts/round-robin-repo-file.sh` | Determines which YAML file receives the next repo entry. Env var `REPO_DATA_FILE_COUNT` (default 50) controls target file count. |
| `scripts/split-repositories-yaml.sh` | Retroactive rebalancing: splits YAML files exceeding a threshold (default 200 repos/file). |
| `scripts/shard-init.sh` | `terraform init` for a shard: `./scripts/shard-init.sh 001 dev` |
| `scripts/shard-plan.sh` | `terraform plan` for a shard: `./scripts/shard-plan.sh 001 dev` |
| `scripts/shard-apply.sh` | `terraform apply` for a shard: `./scripts/shard-apply.sh 001 dev` |
| `scripts/shard-plan-all.sh` | Discovers all shards from YAML, plans in parallel with throttling. |
| `scripts/global-init.sh` | `terraform init` for the global state: `./scripts/global-init.sh dev` |
| `scripts/global-plan.sh` | `terraform plan` for the global state. |
| `scripts/global-apply.sh` | `terraform apply` for the global state. |
| `scripts/migrate-to-shards.sh` | **Read-only**: generates `terraform state mv` commands to `/tmp/` for review. Never auto-executes. |

### CI/CD Workflows (New)

| Workflow | Purpose |
|---|---|
| `.github/workflows/terraform-sharded-ci.yml` | PR validation: discovers affected shards from diff, plans global + shards via matrix strategy (`max-parallel: 10`). Per-shard concurrency groups. |
| `.github/workflows/terraform-sharded-apply.yml` | Push-to-main apply: validates state-group topics, applies global first, then shards in parallel. Supports manual dispatch with explicit shard IDs. |

---

## Files Modified

| File | Changes |
|---|---|
| `.github/workflows/repository-create.yml` | Added round-robin file selection step before YAML update. Updated queue branch merge detection and git add to scan `data/repositories*.yaml`. |
| `.github/workflows/onboard-unmanaged-repos.yml` | Discovery step now scans all `repositories*.yaml` files. Appends new repos using round-robin distribution. Updated git add and PR body. |
| `.github/workflows/terraform-apply.yml` | `check-repos-yaml` job detects changes in any `data/repositories*.yaml`. Archive detection and new-repo auto-detection scan all YAML files. |
| `scripts/split-repositories-yaml.sh` | Updated header documentation to reference round-robin for new repos. |

---

## Files NOT Modified (State Preservation)

| File | Reason |
|---|---|
| `main.tf` | Manages existing monolithic state — must not be changed |
| `variables.tf` | Part of monolithic root config |
| `outputs.tf` | Part of monolithic root config |
| `versions.tf` | Part of monolithic root config |
| `data/repositories.yaml` | No data modifications; only workflow logic changed |
| `data/teams.yaml` | Unchanged |
| `data/defaults.yaml` | Unchanged |
| `environments/**` | Unchanged |
| `modules/**` | Unchanged (shared by all root configs) |

---

## Architecture Summary

```
                                    ┌──────────────────┐
                                    │ data/             │
                                    │ repositories.yaml │
                                    │ repositories-002  │
                                    │ repositories-003  │
                                    │ ...               │
                                    │ teams.yaml        │
                                    └────────┬─────────┘
                                             │
                     ┌───────────────────────┼───────────────────────┐
                     │                       │                       │
              ┌──────▼──────┐        ┌───────▼───────┐       ┌──────▼──────┐
              │   main.tf   │        │   global/     │       │   shards/   │
              │ (MONOLITH)  │        │  main.tf      │       │  main.tf    │
              │  UNTOUCHED  │        │               │       │             │
              └──────┬──────┘        └───────┬───────┘       └──────┬──────┘
                     │                       │                      │
              ┌──────▼──────┐        ┌───────▼───────┐    ┌────────▼────────┐
              │  github.    │        │ github-global. │    │ github-shard-   │
              │  terraform. │        │ terraform.     │    │ 001.terraform.  │
              │  tfstate    │        │ tfstate        │    │ tfstate         │
              │ (EXISTING)  │        │ (NEW)          │    │ (NEW × N)       │
              └─────────────┘        └────────────────┘    └─────────────────┘
```

### State Separation

| State File | Manages | Config |
|---|---|---|
| `github.terraform.tfstate` | **All current resources** (org, repos, teams, security) | `main.tf` (root) |
| `github-global.terraform.tfstate` | Org settings + team shells (no repo bindings) | `global/main.tf` |
| `github-shard-NNN.terraform.tfstate` | ≤50 repos + their security configs + team-repo bindings | `shards/main.tf` |

### Round-Robin YAML File Balancing

```
New repo request
       │
       ▼
round-robin-repo-file.sh
  ├── files < REPO_DATA_FILE_COUNT (50)?
  │     └── YES → Create new file (repositories-NNN.yaml)
  │     └── NO  → Pick file with fewest repos
  │
  ▼
Append repo to chosen file
```

YAML file location is **independent** of state-group shard assignment. Repos in `repositories-003.yaml` may belong to `state-group-001`, `state-group-002`, or any other shard.

---

## How To Use

### Assign State Groups to All Repos

```bash
# Auto-assign state-group-NNN topics (scans all YAML files)
./scripts/assign-state-groups.sh [max-per-shard]   # default: 50
```

### Validate State Groups

```bash
# CI guardrail: exits 1 if any repo lacks a topic or shards are oversized
./scripts/validate-state-groups.sh [max-per-shard]
```

### Run the Global State

```bash
./scripts/global-init.sh dev
./scripts/global-plan.sh dev
./scripts/global-apply.sh dev
```

### Run a Specific Shard

```bash
./scripts/shard-init.sh 001 dev
./scripts/shard-plan.sh 001 dev
./scripts/shard-apply.sh 001 dev
```

### Plan All Shards in Parallel

```bash
./scripts/shard-plan-all.sh dev
```

### Generate Migration Commands

```bash
# Review-only — generates /tmp/migration-commands-dev.sh for manual execution
./scripts/migrate-to-shards.sh dev
```

### Split/Rebalance YAML Files Retroactively

```bash
./scripts/split-repositories-yaml.sh [max-repos-per-file]   # default: 200
```

---

## CI/CD Pipeline Overview

### PR Validation (`terraform-sharded-ci.yml`)

```
PR opened / updated
       │
       ▼
discover (detect affected shards from diff)
       │
       ├──► plan-global (if global config / teams changed)
       │
       └──► plan-shard × N (matrix, max-parallel: 10)
              ├── shard 001
              ├── shard 002
              └── shard ...
```

### Apply (`terraform-sharded-apply.yml`)

```
Push to main
       │
       ▼
discover (detect affected shards)
       │
       ▼
validate (state-group topics)
       │
       ▼
apply-global (if needed)
       │
       ▼
apply-shard × N (matrix, max-parallel: 10)
       ├── shard 001
       ├── shard 002
       └── shard ...
```

Each shard has its own concurrency group (`terraform-shard-NNN-apply`) to prevent overlapping applies.

---

## Migration Path

Migration from the monolithic state to shards is **opt-in** and **non-destructive**:

1. **Assign topics:** `./scripts/assign-state-groups.sh`
2. **Generate commands:** `./scripts/migrate-to-shards.sh dev` → review `/tmp/migration-commands-dev.sh`
3. **Pull state:** `terraform state pull > terraform.tfstate`
4. **Execute:** `bash /tmp/migration-commands-dev.sh`
5. **Push states:** Upload each output `.tfstate` to its backend
6. **Verify:** `terraform plan` in `global/` and each shard (expect no changes)
7. **Decommission:** Remove monolithic state after verification

---

## Environment Variables

| Variable | Default | Used By | Purpose |
|---|---|---|---|
| `REPO_DATA_FILE_COUNT` | `50` | `round-robin-repo-file.sh`, workflows | Target number of YAML data files |
| `GITHUB_TOKEN` | — | All Terraform configs | GitHub API authentication |
| `ARM_CLIENT_ID` | — | Backend init | Azure OIDC authentication |
| `ARM_SUBSCRIPTION_ID` | — | Backend init | Azure subscription |
| `ARM_TENANT_ID` | — | Backend init | Azure AD tenant |
