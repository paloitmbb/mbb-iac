# Monolithic → File-Based Shard Migration Guide

This guide walks through migrating the dev environment from the single monolithic
Terraform state (root `main.tf` + `environments/dev/`) to the file-based sharding
model (`global/` + `shards/`).

> ⚠️ The migration script **never modifies remote state**. All destructive steps are
> explicit and require manual execution.

---

## Prerequisites

Set required environment variables before starting:

```bash
export GITHUB_TOKEN="your-github-pat"
export ARM_ACCESS_KEY="your-storage-account-key"
# Alternative: ARM_SAS_TOKEN, or rely on Azure CLI auth
```

---

## Phase 1 — Generate the migration commands

Initialise the monolithic root config so `terraform state list` works, then
generate the split script:

```bash
# Initialise root (monolithic) config
./scripts/init.sh dev

# Dry-run: generate /tmp/migration-commands-dev.sh (no state changes)
./scripts/migrate-to-shards.sh dev

# Review the generated script before proceeding
cat /tmp/migration-commands-dev.sh
```

Expected output files after execution (in Phase 3):

| Local file | Contains |
|---|---|
| `global.tfstate` | `module.github_organization.*` + `module.github_teams.*` (shells only) |
| `shard-repositories.tfstate` | `module.github_repositories.*`, `module.github_security.*`, team-repo bindings |

---

## Phase 2 — Back up the monolithic state

```bash
# Pull remote state to a local file
terraform state pull > terraform.tfstate

# Create a timestamped backup
cp terraform.tfstate terraform.tfstate.backup.$(date +%Y%m%d%H%M%S)

# Verify resources are present before continuing
terraform state list
```

Do not proceed if `terraform state list` returns empty.

---

## Phase 3 — Execute the migration (local file split only)

```bash
bash /tmp/migration-commands-dev.sh
```

Verify each output state file has the expected resources:

```bash
terraform state list -state=global.tfstate
terraform state list -state=shard-repositories.tfstate
```

Check that the sum of resources across both files equals the original count.

---

## Phase 4 — Initialise the new backends

```bash
# Global backend (key: github-global.terraform.tfstate)
./scripts/global-init.sh dev

# Shard backend (key: github-repos-repositories.terraform.tfstate)
./scripts/shard-init.sh repositories.yaml dev
```

If you have additional `repositories-002.yaml` etc., repeat `shard-init.sh` for each.

---

## Phase 5 — Push local state files to the new backends

```bash
# Push global state
cd global/
terraform state push ../global.tfstate
cd ..

# Push shard state
cd shards/
terraform state push ../shard-repositories.tfstate
cd ..
```

---

## Phase 6 — Verify (expect zero changes)

Both plans must show **no changes** before the monolithic state is retired.

```bash
./scripts/global-plan.sh dev
./scripts/shard-plan.sh repositories.yaml dev
```

If unexpected changes appear, compare against `terraform.tfstate.backup.*` and
resolve before applying anything.

---

## Phase 7 — Retire the monolithic state

Once both plans are clean:

1. **Do not delete** the monolithic state blob in Azure yet — keep it as a recovery
   fallback for at least a few days.
2. Remove the obsolete local plan file:
   ```bash
   rm -f environments/dev/tfplan
   ```
3. After a safe holding period, the old blob (`github.terraform.tfstate`) can be
   archived or deleted from the Azure storage container.

---

## Day-to-day workflow after migration

| Task | Old command | New command |
|---|---|---|
| Initialise | `./scripts/init.sh dev` | `./scripts/global-init.sh dev`<br>`./scripts/shard-init.sh repositories.yaml dev` |
| Plan | `./scripts/plan.sh dev` | `./scripts/global-plan.sh dev`<br>`./scripts/shard-plan.sh repositories.yaml dev` |
| Plan all shards | — | `./scripts/shard-plan-all.sh dev` |
| Apply | `./scripts/apply.sh dev` | `./scripts/global-apply.sh dev`<br>`./scripts/shard-apply.sh repositories.yaml dev` |

Org/team changes → operate in `global/`  
Repository/security changes → operate in `shards/`

---

## Recovery

If anything goes wrong after Phase 5, restore the monolithic state:

```bash
# Re-push the backup to the root backend key
./scripts/init.sh dev
terraform state push terraform.tfstate.backup.<timestamp>
```

Then resume using the old `./scripts/plan.sh dev` / `./scripts/apply.sh dev` workflow
until the issue is resolved.

---

## State key reference

| Config | Azure blob key |
|---|---|
| Root (monolithic, retiring) | `github.terraform.tfstate` |
| `global/` | `github-global.terraform.tfstate` |
| `shards/` — `repositories.yaml` | `github-repos-repositories.terraform.tfstate` |
| `shards/` — `repositories-002.yaml` | `github-repos-repositories-002.terraform.tfstate` |
