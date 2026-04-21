#!/bin/bash
set -euo pipefail

# =============================================================================
# Generate migration commands from the monolithic state to file-based shards
# =============================================================================
# Usage: ./scripts/migrate-to-shards.sh <environment>
#
# ⚠️  THIS SCRIPT DOES NOT EXECUTE ANY STATE CHANGES.
# It only GENERATES a migration script at /tmp/migration-commands-<env>.sh
# for you to review, test, and execute manually.
#
# The new file-based sharding model uses each data/repositories*.yaml file
# as the boundary for a Terraform state. This script maps repos from the
# monolithic state to their YAML file and generates `terraform state mv`
# commands to split the monolith accordingly.
#
# Prerequisites:
#   1. The monolithic state must be initialized (old root config)
#   2. Back up the existing state BEFORE executing the generated script
#
# The generated script uses `terraform state mv` with local state files.
# It moves resources FROM the monolithic state TO per-file/global states.
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
echo "  State Migration Plan Generator (File-Based Sharding)"
echo "  Environment: $ENVIRONMENT"
echo "================================================================"
echo ""
echo "ℹ️  This script ONLY generates migration commands for review."
echo "   No state files or managed resources will be modified."
echo ""

# Build repo→file mapping from ALL repository YAML files
echo "📋 Building repository → YAML file mapping..."
REPO_FILE_MAP=$(python3 -c "
import yaml, json, glob, os

data_dir = '$DATA_DIR'
files = sorted(glob.glob(os.path.join(data_dir, 'repositories*.yaml')))
mapping = {}
for fpath in files:
    basename = os.path.basename(fpath)
    with open(fpath) as f:
        data = yaml.safe_load(f) or {}
    for repo in data.get('repositories', []):
        mapping[repo['name']] = basename
print(json.dumps(mapping))
")

MAPPED_COUNT=$(echo "$REPO_FILE_MAP" | python3 -c 'import sys,json; print(len(json.load(sys.stdin)))')
echo "Found $MAPPED_COUNT repo-to-file assignments"

# List unique YAML files
YAML_FILES=$(echo "$REPO_FILE_MAP" | python3 -c "
import sys, json
m = json.load(sys.stdin)
for f in sorted(set(m.values())):
    print(f)
")
echo "YAML files: $(echo $YAML_FILES | tr '\n' ' ')"

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
# AUTO-GENERATED STATE MIGRATION COMMANDS (File-Based Sharding)
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
#
# State key naming:
#   repositories.yaml     → github-repos-repositories.terraform.tfstate
#   repositories-002.yaml → github-repos-repositories-002.terraform.tfstate
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
echo "# ═══ File-Based Shard States: Repositories + Security + Team-Repo Bindings ═══" >> "$MIGRATION_SCRIPT"

# Repository resources → file-based shard states
echo "$STATE_LIST" | grep '^module.github_repositories\[' | while read -r resource; do
    repo_name=$(echo "$resource" | sed -n 's/^module\.github_repositories\["\([^"]*\)"\].*/\1/p')
    if [ -n "$repo_name" ]; then
        yaml_file=$(echo "$REPO_FILE_MAP" | python3 -c "import sys,json; m=json.load(sys.stdin); print(m.get('$repo_name','UNKNOWN'))")
        if [ "$yaml_file" != "UNKNOWN" ]; then
            state_base=$(echo "$yaml_file" | sed 's/\.yaml$//')
            state_file="shard-${state_base}.tfstate"
            echo "echo '  Moving $resource → $state_file'" >> "$MIGRATION_SCRIPT"
            echo "terraform state mv -state=terraform.tfstate -state-out=$state_file '$resource' '$resource'" >> "$MIGRATION_SCRIPT"
        else
            echo "# WARNING: $resource has no YAML file assignment — skipped" >> "$MIGRATION_SCRIPT"
        fi
    fi
done

# Security resources → file-based shard states
echo "$STATE_LIST" | grep '^module.github_security\[' | while read -r resource; do
    repo_name=$(echo "$resource" | sed -n 's/^module\.github_security\["\([^"]*\)"\].*/\1/p')
    if [ -n "$repo_name" ]; then
        yaml_file=$(echo "$REPO_FILE_MAP" | python3 -c "import sys,json; m=json.load(sys.stdin); print(m.get('$repo_name','UNKNOWN'))")
        if [ "$yaml_file" != "UNKNOWN" ]; then
            state_base=$(echo "$yaml_file" | sed 's/\.yaml$//')
            state_file="shard-${state_base}.tfstate"
            echo "echo '  Moving $resource → $state_file'" >> "$MIGRATION_SCRIPT"
            echo "terraform state mv -state=terraform.tfstate -state-out=$state_file '$resource' '$resource'" >> "$MIGRATION_SCRIPT"
        fi
    fi
done

# Team-repo bindings → file-based shard states
echo "$STATE_LIST" | grep 'github_team_repository' | while read -r resource; do
    repo_name=$(echo "$resource" | sed -n 's/.*github_team_repository\.this\["\([^"]*\)"\].*/\1/p')
    team_name=$(echo "$resource" | sed -n 's/^module\.github_teams\["\([^"]*\)"\].*/\1/p')
    if [ -n "$repo_name" ] && [ -n "$team_name" ]; then
        yaml_file=$(echo "$REPO_FILE_MAP" | python3 -c "import sys,json; m=json.load(sys.stdin); print(m.get('$repo_name','UNKNOWN'))")
        if [ "$yaml_file" != "UNKNOWN" ]; then
            state_base=$(echo "$yaml_file" | sed 's/\.yaml$//')
            state_file="shard-${state_base}.tfstate"
            new_address="github_team_repository.this[\"${team_name}/${repo_name}\"]"
            echo "echo '  Moving $resource → $state_file as ${new_address}'" >> "$MIGRATION_SCRIPT"
            echo "terraform state mv -state=terraform.tfstate -state-out=$state_file '$resource' '${new_address}'" >> "$MIGRATION_SCRIPT"
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
echo "  2. Push each shard-<filename>.tfstate to its shard backend:"
echo "     cd shards/ && terraform state push ../shard-repositories.tfstate"
echo "     cd shards/ && terraform state push ../shard-repositories-002.tfstate"
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
