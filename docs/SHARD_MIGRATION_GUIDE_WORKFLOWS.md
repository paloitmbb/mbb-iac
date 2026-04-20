# Monolithic → File-Based Shard Migration Guide (GitHub Actions)

This guide covers migrating from the monolithic Terraform state to the file-based
sharding model (`global/` + `shards/`) using the three migration workflows.
It also covers how to fully revert to the monolithic state if something goes wrong.

---

## Overview

The migration is split across three manually-triggered workflows to provide a
review gate between each destructive step.

```
migrate-1-generate.yml   →  (review artifact)  →  migrate-2-execute.yml   →  (review logs)  →  migrate-3-push-verify.yml
    No state changes              ↑                   Local split only             ↑                  Pushes to backends
                              Download &                                       Review run           Verifies with plans
                              review script                                    logs first
```

| Workflow                    | Modifies remote state? | Safe to re-run?                          |
| --------------------------- | ---------------------- | ---------------------------------------- |
| `migrate-1-generate.yml`    | No                     | Yes                                      |
| `migrate-2-execute.yml`     | No                     | Yes                                      |
| `migrate-3-push-verify.yml` | **Yes**                | Only if step 2 artifacts are still valid |

After migration, `terraform-sharded-apply.yml` is the primary day-to-day workflow.
It runs five jobs automatically on push:

| Job                         | Purpose                                                                         |
| --------------------------- | ------------------------------------------------------------------------------- |
| `discover`                  | Detects which `data/repositories*.yaml` files changed                           |
| `apply-global`              | Applies org/team state when `global/**` changes                                 |
| `apply-shard`               | Applies each affected shard in parallel (max 10 concurrent)                     |
| `check-repos-yaml`          | Detects new `- name:` entries added across any shard YAML file                  |
| `seed-repository-template`  | Bootstraps new repos with the matching tech-stack template from `mbb-repo-templates` |

---

## Before you start

### Verify secrets are configured

The workflows use the same secrets as the existing CI. Confirm these are set on
the target GitHub environment (`dev` or `production`):

| Secret                | Purpose                        |
| --------------------- | ------------------------------ |
| `ORG_GITHUB_TOKEN`    | GitHub provider authentication |
| `ARM_CLIENT_ID`       | Azure OIDC client              |
| `ARM_TENANT_ID`       | Azure OIDC tenant              |
| `ARM_SUBSCRIPTION_ID` | Azure OIDC subscription        |

### Note the monolithic state blob key

The monolithic state lives at:

```
Storage account : mbbtfstate
Container       : tfstate
Blob key        : github.terraform.tfstate          (dev)
                  github-production.terraform.tfstate (production)
```

**This blob is never deleted by the migration workflows.** It is your recovery
fallback and must be kept until the new shards are confirmed stable.

---

## Step 1 — Generate the migration plan

**Workflow:** `State Migration: 1 - Generate Plan`

1. Go to **Actions → State Migration: 1 - Generate Plan → Run workflow**
2. Select the target environment (`dev` or `production`)
3. Click **Run workflow**

When the run finishes:

- Open the run summary
- Download the artifact `migration-script-<env>-<run-id>`
- Open the `.sh` file and verify:
  - Every `module.github_organization.*` → `global.tfstate`
  - Every `module.github_teams.*` (non-repo-binding) → `global.tfstate`
  - Every `module.github_repositories[*].*` → `shard-repositories.tfstate`
  - Every `module.github_security[*].*` → `shard-repositories.tfstate`
  - Any `github_team_repository` → `shard-repositories.tfstate`
  - No `WARNING` comments for unmapped repos (if present, add the repo to a YAML file first)

Do **not** proceed to step 2 until the script looks correct.

---

## Step 2 — Execute the state split

**Workflow:** `State Migration: 2 - Execute Split`

1. Go to **Actions → State Migration: 2 - Execute Split → Run workflow**
2. Select the same environment as step 1
3. Optionally paste the step 1 run ID in `generate-run-id` for audit trail
4. Click **Run workflow**

When the run finishes, check the **Verify output state files** step in the logs:

```
=== global.tfstate ===
module.github_organization.github_organization_settings.this
module.github_teams["backend-team"].github_team.this
...

=== shard-repositories.tfstate ===
module.github_repositories["mbb-web-portal"].github_repository.this
module.github_security["mbb-web-portal"].github_repository_dependabot_security_updates.this
...

─────────────────────────────────
Monolith:  42 resources
Global:    8  resources
Shards:    34 resources
Total out: 42 resources
✅ All resources accounted for
```

The job fails if `Total out` ≠ `Monolith`. If it fails:

- Check for `WARNING` comments in the generated script (unmapped repos)
- Add any untracked repos to a `data/repositories*.yaml` file
- Re-run steps 1 and 2

Note the **run ID** of this workflow — you need it in step 3.

---

## Step 3 — Push state and verify

**Workflow:** `State Migration: 3 - Push & Verify`

> ⚠️ This step **modifies remote state**. Confirm step 2 logs are clean first.

1. Go to **Actions → State Migration: 3 - Push & Verify → Run workflow**
2. Select the same environment
3. Paste the **run ID from step 2** into `execute-run-id`
4. Click **Run workflow**

The workflow:

- Downloads the `.tfstate` artifacts from step 2
- Pushes `global.tfstate` → `github-global.terraform.tfstate`
- Pushes `shard-repositories.tfstate` → `github-repos-repositories.terraform.tfstate`
- Runs `terraform plan -detailed-exitcode` on each — **fails if any changes are detected**

A successful run ends with:

```
✅ Global plan: no changes
✅ Shard plan for repositories.yaml: no changes
```

The job summary also lists the post-migration steps.

---

## Post-migration

After step 3 succeeds:

1. **Update your CI** — `terraform-apply.yml` now only triggers on `.tf` / `.tfvars`
   changes (YAML path triggers were removed). All `data/repositories*.yaml` changes
   are handled exclusively by `terraform-sharded-apply.yml`. Stop using
   `terraform-apply.yml` for repository YAML changes.

2. **Remove the stale plan file** (if present):
   Open a PR to delete `environments/dev/tfplan` from the repository.

3. **Keep the monolithic blob for a holding period** — do not delete
   `github.terraform.tfstate` from the storage container for at least 5 business days
   after the migration is confirmed stable.

4. **Set the `REPO_DATA_FILE_COUNT` repository variable** — go to repository
   **Settings → Actions → Variables** and set `REPO_DATA_FILE_COUNT = 50`.
   This controls how many shard files the round-robin balancer will create before
   it starts filling existing files.

5. **Day-to-day workflow going forward:**

   | Task                        | Trigger                                                                  |
   | --------------------------- | ------------------------------------------------------------------------ |
   | Org / team changes          | Push to `global/**` → `terraform-sharded-apply.yml` runs global job      |
   | Repository YAML changes     | Push to `data/repositories*.yaml` → `terraform-sharded-apply.yml` auto-applies affected shards |
   | Module / shard config change | Push to `modules/**` or `shards/**` → all shards apply in parallel      |
   | New repo seeding             | Automatic — `seed-repository-template` job runs after apply if a `- name:` line was added |
   | Plan all shards locally      | `./scripts/shard-plan-all.sh dev`                                        |

---

## Revert: full rollback to the monolithic state

Use this if step 3 produces unexpected plan changes or if the new shards behave
incorrectly after migration.

### When to revert

- `terraform plan` on a shard shows resource recreation or unexpected diffs
- A `terraform apply` on a shard produced unintended changes to GitHub resources
- The global or shard state push failed mid-way leaving partial state

### Revert procedure

#### Option A — revert via workflow (recommended)

The existing `terraform-apply.yml` workflow still points at the monolithic root
config and the original backend key (`github.terraform.tfstate`). Since that blob
was never modified, it can be used immediately.

1. Go to **Actions → Terraform Apply - Infrastructure → Run workflow**
2. Select the environment
3. The workflow inits against the original monolithic backend key and runs plan/apply

This resumes normal monolithic operation without touching the shard backends.

#### Option B — revert via a manual recovery workflow

If the monolithic `terraform-apply.yml` no longer runs cleanly (e.g. `.tf` files
in root were modified), create a one-off `workflow_dispatch` workflow:

```yaml
name: "State Migration: Revert to Monolithic"

on:
  workflow_dispatch:
    inputs:
      environment:
        required: true
        type: choice
        options: [dev, production]
        default: dev

permissions:
  contents: read
  id-token: write

jobs:
  revert:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    steps:
      - uses: actions/checkout@v4

      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.ARM_CLIENT_ID }}
          tenant-id: ${{ secrets.ARM_TENANT_ID }}
          subscription-id: ${{ secrets.ARM_SUBSCRIPTION_ID }}

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.14.5"
          terraform_wrapper: false

      - name: Init monolithic root (original backend key)
        run: |
          terraform init \
            -backend-config="environments/${{ inputs.environment }}/backend.tfvars"
        env:
          GITHUB_TOKEN: ${{ secrets.ORG_GITHUB_TOKEN }}
          ARM_CLIENT_ID: ${{ secrets.ARM_CLIENT_ID }}
          ARM_TENANT_ID: ${{ secrets.ARM_TENANT_ID }}
          ARM_SUBSCRIPTION_ID: ${{ secrets.ARM_SUBSCRIPTION_ID }}
          ARM_USE_OIDC: true

      - name: Verify monolithic state is intact
        run: |
          COUNT=$(terraform state list 2>/dev/null | wc -l | tr -d ' ')
          echo "Monolithic state has $COUNT resources"
          if [ "$COUNT" -eq 0 ]; then
            echo "❌ Monolithic state is empty — cannot revert"
            exit 1
          fi
        env:
          GITHUB_TOKEN: ${{ secrets.ORG_GITHUB_TOKEN }}
          ARM_CLIENT_ID: ${{ secrets.ARM_CLIENT_ID }}
          ARM_TENANT_ID: ${{ secrets.ARM_TENANT_ID }}
          ARM_SUBSCRIPTION_ID: ${{ secrets.ARM_SUBSCRIPTION_ID }}
          ARM_USE_OIDC: true

      - name: Terraform plan (monolithic)
        run: |
          terraform plan \
            -var-file="environments/${{ inputs.environment }}/terraform.tfvars" \
            -lock=false
        env:
          GITHUB_TOKEN: ${{ secrets.ORG_GITHUB_TOKEN }}
          ARM_CLIENT_ID: ${{ secrets.ARM_CLIENT_ID }}
          ARM_TENANT_ID: ${{ secrets.ARM_TENANT_ID }}
          ARM_SUBSCRIPTION_ID: ${{ secrets.ARM_SUBSCRIPTION_ID }}
          ARM_USE_OIDC: true
```

After confirming the plan is clean, add an `apply` step or trigger the existing
`terraform-apply.yml`.

#### Cleaning up partial shard state (if needed)

If the shard backends were partially populated and you want to clear them so they
do not interfere:

```bash
# Delete the shard and global blobs from Azure (safe — GitHub resources are untouched)
az storage blob delete \
  --account-name mbbtfstate \
  --container-name tfstate \
  --name github-global.terraform.tfstate

az storage blob delete \
  --account-name mbbtfstate \
  --container-name tfstate \
  --name github-repos-repositories.terraform.tfstate
```

This leaves the monolithic blob (`github.terraform.tfstate`) intact as the sole
source of truth.

---

## State blob reference

| Config                                         | Azure blob key                                    |
| ---------------------------------------------- | ------------------------------------------------- |
| Root — monolithic (original, kept as fallback) | `github.terraform.tfstate`                        |
| Root — production monolithic                   | `github-production.terraform.tfstate`             |
| `global/`                                      | `github-global.terraform.tfstate`                 |
| `shards/` — `repositories.yaml`                | `github-repos-repositories.terraform.tfstate`     |
| `shards/` — `repositories-002.yaml`            | `github-repos-repositories-002.terraform.tfstate` |

---

## Troubleshooting

### Step 2 fails: resource count mismatch

A repo in the monolithic state has no matching entry in any `data/repositories*.yaml`.
Check the `WARNING` comments in the generated script, add the repo to a YAML file,
then re-run steps 1 and 2.

### Step 3 fails: plan shows changes after push

The state was pushed but Terraform sees drift. Do **not** apply. Instead:

- Download the plan output from the job logs
- Compare against the monolithic state to identify what differs
- If the diff is benign (ordering, computed fields), re-run step 3 — plans are idempotent
- If the diff is destructive, revert using Option A above

### Step 3 fails: artifact not found

The 3-day artifact retention on step 2 has expired, or the wrong run ID was used.
Re-run step 2 to regenerate the split state files, then retry step 3 with the new run ID.

### Shard backend already has state

If `terraform state push` fails with a serial conflict, the shard backend already
contains a newer state. Check whether a previous partial migration pushed state:

```bash
az storage blob list \
  --account-name mbbtfstate \
  --container-name tfstate \
  --query "[].name" -o tsv | grep github-
```

If an unexpected blob exists, delete it (see cleanup steps above) and re-run step 3.
