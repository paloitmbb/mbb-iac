# File-Based State Sharding — Implementation Summary

**Date:** 19 April 2026
**Status:** ✅ Implementation Complete
**Plan Reference:** [05-FILE_BASED_STATE_SHARDING_PLAN.md](./05-FILE_BASED_STATE_SHARDING_PLAN.md)

---

## Overview

The state sharding approach has been simplified from **topic-based** (each repo carries a `state-group-NNN` topic) to **file-based** (each `data/repositories*.yaml` file maps directly to its own Terraform state).

This eliminates the need for state-group topic assignment/validation scripts, and makes the YAML filename the single source of truth for which Terraform state manages a repository.

---

## What Changed

### Terraform Config (`shards/`)

| File | Change |
|---|---|
| `shards/main.tf` | Loads only **one** YAML file via `var.repositories_file` (no topic filtering, no `fileset` across all files) |
| `shards/variables.tf` | Replaced `var.shard_id` (3-digit string) with `var.repositories_file` (e.g., `"repositories-002.yaml"`) |
| `shards/outputs.tf` | Outputs `repositories_file` instead of `shard_id`/`shard_topic` |
| `shards/versions.tf` | Updated state key comment: `github-repos-<filename>.terraform.tfstate` |

### Scripts

| Script | Change |
|---|---|
| `scripts/shard-init.sh` | Accepts `<repositories_file>` instead of `<shard_id>`. Derives state key from filename. |
| `scripts/shard-plan.sh` | Accepts `<repositories_file>`. Passes `-var="repositories_file=..."`. |
| `scripts/shard-apply.sh` | Accepts `<repositories_file>`. Uses filename-derived plan file. |
| `scripts/shard-plan-all.sh` | Discovers YAML files via `find`, not shard topics from YAML. |
| `scripts/migrate-to-shards.sh` | Builds repo→YAML-file mapping (not repo→shard-topic). Generates state filenames from YAML filenames. |
| `scripts/round-robin-repo-file.sh` | Updated docs: now directly controls state boundaries. |
| `scripts/split-repositories-yaml.sh` | Updated docs: moving repos between files changes state binding. |

### Scripts Removed

| Script | Reason |
|---|---|
| `scripts/assign-state-groups.sh` | No longer needed — no `state-group-NNN` topics to assign. |
| `scripts/validate-state-groups.sh` | No longer needed — no topics to validate. |

### CI/CD Workflows

| Workflow | Change |
|---|---|
| `terraform-sharded-ci.yml` | Matrix iterates over YAML filenames (not shard IDs). Detects changed `data/repositories*.yaml` files from PR diff. |
| `terraform-sharded-apply.yml` | Matrix iterates over YAML filenames. Removed validate job (no state-group topics). Manual dispatch accepts `repo-files` (comma-separated filenames) instead of `shard-ids`. |

---

## Files NOT Modified

| File | Reason |
|---|---|
| `main.tf` | Manages existing monolithic state — must not be changed |
| `variables.tf` | Part of monolithic root config |
| `outputs.tf` | Part of monolithic root config |
| `versions.tf` | Part of monolithic root config |
| `global/` | No changes needed — global state is unaffected |
| `data/` | No data modifications |
| `environments/` | Unchanged |
| `modules/` | Unchanged (shared by all root configs) |

---

## Architecture

```
data/repositories.yaml       →  github-repos-repositories.terraform.tfstate
data/repositories-002.yaml   →  github-repos-repositories-002.terraform.tfstate
data/repositories-003.yaml   →  github-repos-repositories-003.terraform.tfstate
...

                              +  github-global.terraform.tfstate  (org + teams)
                              +  github.terraform.tfstate          (monolith, untouched)
```

### Data Flow

```
round-robin-repo-file.sh
  ├── files < REPO_DATA_FILE_COUNT (50)?
  │     └── YES → Create new YAML file (= new Terraform state)
  │     └── NO  → Append to file with fewest repos
  │
  ▼
data/repositories-NNN.yaml  ←  new repo added here
  │
  ▼
CI detects changed file
  │
  ▼
terraform init -backend-config="key=github-repos-repositories-NNN.terraform.tfstate"
terraform plan -var="repositories_file=repositories-NNN.yaml"
terraform apply
```

---

## How To Use

### Run a Specific Shard

```bash
./scripts/shard-init.sh repositories.yaml dev
./scripts/shard-plan.sh repositories.yaml dev
./scripts/shard-apply.sh repositories.yaml dev

# Or for a split file:
./scripts/shard-init.sh repositories-002.yaml dev
./scripts/shard-plan.sh repositories-002.yaml dev
./scripts/shard-apply.sh repositories-002.yaml dev
```

### Plan All Shards in Parallel

```bash
./scripts/shard-plan-all.sh dev         # default: 5 parallel
./scripts/shard-plan-all.sh dev 10      # override parallel count
```

### Generate Migration Commands

```bash
./scripts/migrate-to-shards.sh dev
# Review: cat /tmp/migration-commands-dev.sh
```

### Manual Dispatch (CI)

For `terraform-sharded-apply.yml`:
- **repo-files**: `repositories.yaml,repositories-002.yaml` (comma-separated)
- **apply-global**: `true` / `false`

---

## CI/CD Pipeline

### PR Validation (`terraform-sharded-ci.yml`)

```
PR opened / updated
       │
       ▼
discover (detect changed YAML filenames from diff)
       │
       ├──► plan-global (if global/modules/envs changed)
       │
       └──► plan-shard × N (matrix, max-parallel: 10)
              ├── repositories.yaml
              ├── repositories-002.yaml
              └── (only changed files)
```

### Apply (`terraform-sharded-apply.yml`)

```
Push to main
       │
       ▼
discover (detect changed YAML filenames)
       │
       ▼
apply-global (if needed)
       │
       ▼
apply-shard × N (matrix, max-parallel: 10)
       ├── repositories.yaml          ← only if changed
       ├── repositories-002.yaml      ← only if changed
       └── ...
```

---

## Migration Path

The migration maps each repo to its YAML file (not a shard topic):

1. **Generate commands:** `./scripts/migrate-to-shards.sh dev`
2. **Pull state:** `terraform state pull > terraform.tfstate`
3. **Execute:** `bash /tmp/migration-commands-dev.sh`
4. **Push states:** Upload each output `.tfstate` to its backend key
5. **Verify:** `terraform plan` in `global/` and each shard

---

## Environment Variables

| Variable | Default | Used By | Purpose |
|---|---|---|---|
| `REPO_DATA_FILE_COUNT` | `50` | `round-robin-repo-file.sh`, workflows | Target number of YAML files (= states) |
| `GITHUB_TOKEN` | — | All Terraform configs | GitHub API authentication |
| `ARM_CLIENT_ID` | — | Backend init | Azure OIDC authentication |
| `ARM_SUBSCRIPTION_ID` | — | Backend init | Azure subscription |
| `ARM_TENANT_ID` | — | Backend init | Azure AD tenant |
