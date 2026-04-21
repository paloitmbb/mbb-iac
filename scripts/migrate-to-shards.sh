#!/bin/bash
set -euo pipefail

# =============================================================================
# Generate migration commands from the monolithic state to sharded states
# =============================================================================
# Usage: ./scripts/migrate-to-shards.sh <environment>
#
# ⚠️  THIS SCRIPT DOES NOT EXECUTE ANY STATE CHANGES.
# It only GENERATES a migration script at /tmp/migration-commands-<env>.sh
# for you to review, test, and execute manually.
#
# Prerequisites:
#   1. All repos must have state-group-NNN topics assigned
#      (run ./scripts/assign-state-groups.sh first)
#   2. The monolithic state must be initialized (old root config)
#   3. Back up the existing state BEFORE executing the generated script
#
# The generated script uses `terraform state mv` with local state files.
# It moves resources FROM the monolithic state TO per-shard/global states.
# The existing monolithic state and managed resources remain untouched
# until you explicitly execute the generated script.
#
# Workflow:
#   1. Run this script → generates /tmp/migration-commands-<env>.sh
#   2. Review the generated script carefully
#   3. Pull the monolithic state locally: terraform state pull > terraform.tfstate
#   4. Execute the generated script
#   5. Push each output state file to its new backend
#   6. Verify with terraform plan in global/ and shards/
# =============================================================================

if [ -z "${1:-}" ]; then
    echo "Usage: ./scripts/migrate-to-shards.sh <environment>"
    echo "Example: ./scripts/migrate-to-shards.sh dev"
    exit 1
fi

ENVIRONMENT=$1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$PROJECT_ROOT/data"

echo "================================================================"
echo "  State Migration Plan Generator"
echo "  Environment: $ENVIRONMENT"
echo "================================================================"
echo ""
echo "ℹ️  This script ONLY generates migration commands for review."
echo "   No state files or managed resources will be modified."
echo ""

# Build repo→shard mapping from ALL repository YAML files
echo "📋 Building repository → shard mapping..."
REPO_SHARD_MAP=$(python3 -c "
import yaml, re, json, glob, os

data_dir = '$DATA_DIR'
files = sorted(glob.glob(os.path.join(data_dir, 'repositories*.yaml')))
mapping = {}
for fpath in files:
    with open(fpath) as f:
        data = yaml.safe_load(f) or {}
    for repo in data.get('repositories', []):
        name = repo['name']
        for t in repo.get('topics', []):
            m = re.match(r'^state-group-(\d{3})$', t)
            if m:
                mapping[name] = m.group(1)
                break
print(json.dumps(mapping))
")

MAPPED_COUNT=$(echo "$REPO_SHARD_MAP" | python3 -c 'import sys,json; print(len(json.load(sys.stdin)))')
echo "Found $MAPPED_COUNT repo-to-shard assignments"

# List resources in monolithic state
echo ""
echo "📥 Listing resources in monolithic state..."
cd "$PROJECT_ROOT"
STATE_LIST=$(terraform state list 2>/dev/null || echo "")

if [ -z "$STATE_LIST" ]; then
    echo "  No resources found in monolithic state (already migrated or not initialized)"
    exit 0
fi

RESOURCE_COUNT=$(echo "$STATE_LIST" | wc -l | tr -d ' ')
echo "  Found $RESOURCE_COUNT resources in monolithic state"

# Generate migration commands (write-only to /tmp, never executed)
echo ""
echo "📝 Generating migration commands..."

MIGRATION_SCRIPT="/tmp/migration-commands-${ENVIRONMENT}.sh"
cat > "$MIGRATION_SCRIPT" << 'HEADER'
#!/bin/bash
set -e
# =============================================================================
# AUTO-GENERATED STATE MIGRATION COMMANDS
# =============================================================================
# Review this script carefully before executing!
#
# Prerequisites:
#   1. Pull monolithic state locally FIRST:
#      cd <project-root> && terraform state pull > terraform.tfstate
#   2. Back up terraform.tfstate before proceeding
#   3. Run this script from the project root directory
#
# This script uses 'terraform state mv' with local state files.
# It does NOT modify the remote backend directly.
# After execution, you must push each output file to its backend.
# =============================================================================

echo "Starting state migration..."
echo ""
HEADER

echo "" >> "$MIGRATION_SCRIPT"
echo "# ═══ Global State: Organization + Teams (no repo bindings) ═══" >> "$MIGRATION_SCRIPT"

# Organization resources
echo "$STATE_LIST" | grep '^module.github_organization' | while read -r resource; do
    echo "echo '  Moving $resource → global state'" >> "$MIGRATION_SCRIPT"
    echo "terraform state mv -state=terraform.tfstate -state-out=global.tfstate '$resource' '$resource'" >> "$MIGRATION_SCRIPT"
done

# Team resources (team shells, memberships — but NOT team_repository)
echo "$STATE_LIST" | grep '^module.github_teams' | grep -v 'github_team_repository' | while read -r resource; do
    echo "echo '  Moving $resource → global state'" >> "$MIGRATION_SCRIPT"
    echo "terraform state mv -state=terraform.tfstate -state-out=global.tfstate '$resource' '$resource'" >> "$MIGRATION_SCRIPT"
done

echo "" >> "$MIGRATION_SCRIPT"
echo "# ═══ Shard States: Repositories + Security + Team-Repo Bindings ═══" >> "$MIGRATION_SCRIPT"

# Repository resources → shard states
echo "$STATE_LIST" | grep '^module.github_repositories\[' | while read -r resource; do
    repo_name=$(echo "$resource" | sed -n 's/^module\.github_repositories\["\([^"]*\)"\].*/\1/p')
    if [ -n "$repo_name" ]; then
        shard_id=$(echo "$REPO_SHARD_MAP" | python3 -c "import sys,json; m=json.load(sys.stdin); print(m.get('$repo_name','UNKNOWN'))")
        if [ "$shard_id" != "UNKNOWN" ]; then
            echo "echo '  Moving $resource → shard-${shard_id} state'" >> "$MIGRATION_SCRIPT"
            echo "terraform state mv -state=terraform.tfstate -state-out=shard-${shard_id}.tfstate '$resource' '$resource'" >> "$MIGRATION_SCRIPT"
        else
            echo "# WARNING: $resource has no shard assignment — skipped" >> "$MIGRATION_SCRIPT"
        fi
    fi
done

# Security resources → shard states
echo "$STATE_LIST" | grep '^module.github_security\[' | while read -r resource; do
    repo_name=$(echo "$resource" | sed -n 's/^module\.github_security\["\([^"]*\)"\].*/\1/p')
    if [ -n "$repo_name" ]; then
        shard_id=$(echo "$REPO_SHARD_MAP" | python3 -c "import sys,json; m=json.load(sys.stdin); print(m.get('$repo_name','UNKNOWN'))")
        if [ "$shard_id" != "UNKNOWN" ]; then
            echo "echo '  Moving $resource → shard-${shard_id} state'" >> "$MIGRATION_SCRIPT"
            echo "terraform state mv -state=terraform.tfstate -state-out=shard-${shard_id}.tfstate '$resource' '$resource'" >> "$MIGRATION_SCRIPT"
        fi
    fi
done

# Team-repo bindings → shard states (these need address rewriting)
echo "$STATE_LIST" | grep 'github_team_repository' | while read -r resource; do
    repo_name=$(echo "$resource" | sed -n 's/.*github_team_repository\.this\["\([^"]*\)"\].*/\1/p')
    team_name=$(echo "$resource" | sed -n 's/^module\.github_teams\["\([^"]*\)"\].*/\1/p')
    if [ -n "$repo_name" ] && [ -n "$team_name" ]; then
        shard_id=$(echo "$REPO_SHARD_MAP" | python3 -c "import sys,json; m=json.load(sys.stdin); print(m.get('$repo_name','UNKNOWN'))")
        if [ "$shard_id" != "UNKNOWN" ]; then
            new_address="github_team_repository.this[\"${team_name}/${repo_name}\"]"
            echo "echo '  Moving $resource → shard-${shard_id} state as ${new_address}'" >> "$MIGRATION_SCRIPT"
            echo "terraform state mv -state=terraform.tfstate -state-out=shard-${shard_id}.tfstate '$resource' '${new_address}'" >> "$MIGRATION_SCRIPT"
        fi
    fi
done

cat >> "$MIGRATION_SCRIPT" << 'FOOTER'

echo ""
echo "✅ State migration commands complete."
echo ""
echo "Next steps:"
echo "  1. Push global.tfstate to the global backend:"
echo "     cd global/ && terraform state push ../global.tfstate"
echo "  2. Push each shard-NNN.tfstate to its shard backend:"
echo "     cd shards/ && terraform state push ../shard-NNN.tfstate"
echo "  3. Verify each config with terraform plan (expect no changes)"
echo "  4. The monolithic terraform.tfstate should now be empty or near-empty"
FOOTER

chmod +x "$MIGRATION_SCRIPT"

echo ""
echo "✅ Migration script generated: $MIGRATION_SCRIPT"
echo ""
echo "This script is READ-ONLY output. No state was modified."
echo ""
echo "To execute the migration when ready:"
echo "  1. Review:  cat $MIGRATION_SCRIPT"
echo "  2. Backup:  terraform state pull > terraform.tfstate.backup"
echo "  3. Pull:    terraform state pull > terraform.tfstate"
echo "  4. Run:     bash $MIGRATION_SCRIPT"
echo "  5. Push:    Upload each output .tfstate to its backend"
echo "  6. Verify:  terraform plan in global/ and each shard"
