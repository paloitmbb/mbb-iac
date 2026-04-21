#!/bin/bash
set -euo pipefail

# =============================================================================
# Migrate resources from the monolithic state to sharded states
# =============================================================================
# Usage: ./scripts/migrate-to-shards.sh <environment>
#
# Prerequisites:
#   1. All repos must have state-group-NNN topics assigned
#   2. The monolithic state must be initialized (old root config)
#   3. Global and shard states must be initialized
#
# This script:
#   1. Reads data/repositories.yaml to determine shard assignments
#   2. Pulls the monolithic state to a local file
#   3. Moves org + team resources to the global state
#   4. Moves repo + security + team-repo resources to the correct shard state
#   5. Provides a summary of operations
#
# ⚠️  THIS IS A DESTRUCTIVE OPERATION — back up your state files first!
# =============================================================================

if [ -z "${1:-}" ]; then
    echo "Usage: ./scripts/migrate-to-shards.sh <environment>"
    echo "Example: ./scripts/migrate-to-shards.sh dev"
    exit 1
fi

ENVIRONMENT=$1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REPOS_FILE="$PROJECT_ROOT/data/repositories.yaml"

echo "================================================================"
echo "  State Migration: Monolith → Sharded Architecture"
echo "  Environment: $ENVIRONMENT"
echo "================================================================"
echo ""
echo "⚠️  WARNING: This is a destructive operation!"
echo "   Ensure you have backed up your state files before proceeding."
echo ""
read -p "Continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Migration cancelled."
    exit 0
fi

# Build repo→shard mapping
echo ""
echo "📋 Building repository → shard mapping..."
REPO_SHARD_MAP=$(python3 -c "
import yaml, re, json
with open('$REPOS_FILE') as f:
    data = yaml.safe_load(f)
mapping = {}
for repo in data.get('repositories', []):
    name = repo['name']
    for t in repo.get('topics', []):
        m = re.match(r'^state-group-(\d{3})$', t)
        if m:
            mapping[name] = m.group(1)
            break
print(json.dumps(mapping))
")

echo "Found $(echo "$REPO_SHARD_MAP" | python3 -c 'import sys,json; print(len(json.load(sys.stdin)))') repo-to-shard assignments"

# Step 1: Pull monolithic state
echo ""
echo "📥 Step 1: Listing resources in monolithic state..."
cd "$PROJECT_ROOT"
STATE_LIST=$(terraform state list 2>/dev/null || echo "")

if [ -z "$STATE_LIST" ]; then
    echo "  No resources found in monolithic state (may already be migrated)"
    exit 0
fi

echo "  Found $(echo "$STATE_LIST" | wc -l | tr -d ' ') resources in monolithic state"

# Step 2: Generate migration commands
echo ""
echo "📝 Step 2: Generating migration commands..."

MIGRATION_SCRIPT="/tmp/migration-commands-${ENVIRONMENT}.sh"
cat > "$MIGRATION_SCRIPT" << 'HEADER'
#!/bin/bash
set -e
# Auto-generated migration commands
# Review carefully before executing!
HEADER

echo "" >> "$MIGRATION_SCRIPT"
echo "# ═══ Global State: Organization + Teams ═══" >> "$MIGRATION_SCRIPT"

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
            echo "# WARNING: $resource has no shard assignment" >> "$MIGRATION_SCRIPT"
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
    # Extract repo name from the resource
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

chmod +x "$MIGRATION_SCRIPT"

echo ""
echo "✅ Migration script generated: $MIGRATION_SCRIPT"
echo ""
echo "Next steps:"
echo "  1. Review the generated script carefully"
echo "  2. Pull state files locally:"
echo "     terraform state pull > terraform.tfstate"
echo "  3. Run the migration script:"
echo "     bash $MIGRATION_SCRIPT"
echo "  4. Push state files to their new backends:"
echo "     - global.tfstate → github-global.terraform.tfstate"
echo "     - shard-NNN.tfstate → github-shard-NNN.terraform.tfstate"
echo "  5. Verify with terraform plan in each config"
