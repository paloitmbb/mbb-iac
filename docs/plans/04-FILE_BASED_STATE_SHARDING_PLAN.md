# File-Based State Sharding — Implementation Plan

**Date:** 19 April 2026
**Status:** ✅ Implementation Complete
**Summary Reference:** [04-IMPLEMENTATION_SUMMARY.md](./04-IMPLEMENTATION_SUMMARY.md)

---

## Problem

An earlier approach introduced state sharding via `state-group-NNN` repository topics. While functional, this added unnecessary indirection:

- Each repo needed a `state-group-NNN` topic added to its YAML config.
- A separate script (`assign-state-groups.sh`) was required to assign topics.
- A validation script (`validate-state-groups.sh`) was required in CI.
- The YAML file a repo lived in was **independent** of its Terraform state, making the mental model harder to reason about.

---

## New Approach: YAML File = State Boundary

Instead of using topics, **each `data/repositories*.yaml` file maps directly to its own Terraform state**. This is simpler because:

1. **No extra metadata** — repos don't need `state-group-*` topics.
2. **No assignment script** — the round-robin balancer already distributes repos across files.
3. **No validation script** — CI simply detects which files changed.
4. **Intuitive model** — if you add a repo to `repositories-003.yaml`, it goes into the `github-repos-repositories-003.terraform.tfstate` state.
5. **New state on new file** — when the round-robin balancer creates a new YAML file, a new Terraform state is automatically generated on the next apply.

---

## Architecture

```
mbb-iac/
├── main.tf                         # EXISTING monolithic config (UNTOUCHED)
│
├── global/                         # Org settings + team shells
│   ├── main.tf                     # State key: github-global.terraform.tfstate
│   └── ...
│
├── shards/                         # Parameterized by repositories_file
│   ├── main.tf                     # Loads ONE YAML file per invocation
│   ├── variables.tf                # var.repositories_file (e.g., "repositories-002.yaml")
│   └── ...
│
├── data/
│   ├── repositories.yaml           → github-repos-repositories.terraform.tfstate
│   ├── repositories-002.yaml       → github-repos-repositories-002.terraform.tfstate
│   ├── repositories-003.yaml       → github-repos-repositories-003.terraform.tfstate
│   └── ...
│
└── scripts/
    ├── round-robin-repo-file.sh    # Pick target file (now also controls state binding)
    ├── shard-init.sh               # ./scripts/shard-init.sh repositories.yaml dev
    ├── shard-plan.sh               # ./scripts/shard-plan.sh repositories.yaml dev
    ├── shard-apply.sh              # ./scripts/shard-apply.sh repositories.yaml dev
    ├── shard-plan-all.sh           # Plan all files in parallel
    └── migrate-to-shards.sh        # Generate migration commands (review-only)
```

### State Key Convention

Each YAML filename maps to a state key by stripping `.yaml` and prepending `github-repos-`:

| YAML File | State Key |
|---|---|
| `repositories.yaml` | `github-repos-repositories.terraform.tfstate` |
| `repositories-002.yaml` | `github-repos-repositories-002.terraform.tfstate` |
| `repositories-003.yaml` | `github-repos-repositories-003.terraform.tfstate` |

---

## How It Works

### Adding a New Repository

1. Round-robin balancer selects a file (e.g., `repositories-002.yaml`).
2. Repo is appended to that file.
3. CI detects `repositories-002.yaml` changed → only plans that shard.
4. Apply runs only for `github-repos-repositories-002.terraform.tfstate`.

### Creating a New YAML File (New State)

1. Round-robin balancer sees `file count < REPO_DATA_FILE_COUNT` → creates `repositories-004.yaml`.
2. New repo is written to the new file.
3. CI detects new file → terraform init creates a **new** state automatically.
4. Apply creates the state and provisions the repo.

### Modifying Multiple Files

1. CI detects all changed `data/repositories*.yaml` filenames.
2. Matrix strategy runs one job per changed file, in parallel (max 10).
3. Each job inits with the correct state key and applies only its repos.

---

## Design Decisions

### 1. Existing Monolithic State Preserved

The root `main.tf` is **never modified**. Migration is opt-in via `migrate-to-shards.sh`.

### 2. No More `state-group-*` Topics

Repos no longer need `state-group-NNN` topics. The file they reside in IS their state binding. This eliminates `assign-state-groups.sh` and `validate-state-groups.sh`.

### 3. Round-Robin Now Controls State Boundaries

The round-robin balancer (`scripts/round-robin-repo-file.sh`) both distributes repos across files and implicitly controls which Terraform state manages them. The `REPO_DATA_FILE_COUNT` env var (default 50) sets the target number of files/states.

### 4. Only Changed Files Are Planned/Applied

CI workflows detect which `data/repositories*.yaml` files changed in the PR/push. Only those files' corresponding states are planned and applied. This provides the same efficiency as topic-based sharding without the extra indirection.

### 5. Team-Repo Bindings Stay In Shards

Teams are defined in the global state. Team-repo bindings for repos in a given YAML file are managed by that file's shard state, using `data "github_team" "lookup"` for ID resolution.

---

## Comparison: Topic-Based vs File-Based

| Aspect | Topic-Based (old) | File-Based (current) |
|---|---|---|
| State binding mechanism | `state-group-NNN` repo topic | YAML filename |
| Extra repo metadata | Required (topic per repo) | None |
| Assignment script | `assign-state-groups.sh` | Not needed |
| Validation script | `validate-state-groups.sh` | Not needed |
| New state creation | Manual topic assignment | Automatic on new file |
| CI detection | Parse topics from all files | Detect changed filenames |
| Mental model | Topic→state (indirect) | File→state (direct) |
| Round-robin role | Distributes files only | Distributes files AND controls state |
| Total scripts | 12 | 10 |
