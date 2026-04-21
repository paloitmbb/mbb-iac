#!/bin/bash
set -euo pipefail

# =============================================================================
# Discover all repository YAML files and plan each shard in parallel
# =============================================================================
# Usage: ./scripts/shard-plan-all.sh [environment] [max-parallel]
# Example: ./scripts/shard-plan-all.sh dev 5
#
# Each data/repositories*.yaml file maps to its own Terraform state.
# This script discovers all such files and runs a plan for each.
# =============================================================================

ENVIRONMENT=${1:-dev}
MAX_PARALLEL=${2:-5}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$PROJECT_ROOT/data"

echo "Discovering repository YAML files in $DATA_DIR..."

# List all repository YAML files (basenames only)
REPO_FILES=$(find "$DATA_DIR" -maxdepth 1 -name 'repositories*.yaml' -printf '%f\n' | sort)

if [ -z "$REPO_FILES" ]; then
    echo "No repositories*.yaml files found in $DATA_DIR"
    exit 1
fi

FILE_COUNT=$(echo "$REPO_FILES" | wc -l | tr -d ' ')
echo "Found $FILE_COUNT file(s): $(echo $REPO_FILES | tr '\n' ' ')"

# Run plans in parallel (up to MAX_PARALLEL at a time)
echo ""
echo "Planning all shards (max $MAX_PARALLEL parallel)..."
PIDS=()
RUNNING=0
FAILED=0

for REPOS_FILE in $REPO_FILES; do
    # Derive state key from filename
    STATE_KEY_BASE=$(echo "$REPOS_FILE" | sed 's/\.yaml$//')
    STATE_KEY="github-repos-${STATE_KEY_BASE}.terraform.tfstate"
    LOG_FILE="/tmp/shard-${STATE_KEY_BASE}-plan.log"

    echo "  → Starting plan for $REPOS_FILE (state: $STATE_KEY)..."
    (
        cd "$PROJECT_ROOT/shards"
        # Init with file-specific state key (reconfigure to avoid prompt)
        terraform init -reconfigure \
            -backend-config="$PROJECT_ROOT/environments/$ENVIRONMENT/backend.tfvars" \
            -backend-config="key=$STATE_KEY" \
            > /dev/null 2>&1

        ORG_NAME=$(python3 -c "
import re
with open('$PROJECT_ROOT/environments/$ENVIRONMENT/terraform.tfvars') as f:
    m = re.search(r'name\s*=\s*\"([^\"]+)\"', f.read())
    print(m.group(1) if m else 'unknown')
")
        PLAN_NAME=$(echo "$REPOS_FILE" | sed 's/\.yaml$//')
        terraform plan \
            -var="repositories_file=$REPOS_FILE" \
            -var="organization_name=$ORG_NAME" \
            -lock=false \
            -out="$PROJECT_ROOT/environments/$ENVIRONMENT/shard-${PLAN_NAME}-tfplan" \
            > "$LOG_FILE" 2>&1
    ) &
    PIDS+=($!)
    RUNNING=$((RUNNING + 1))

    # Throttle parallel jobs
    if [ $RUNNING -ge "$MAX_PARALLEL" ]; then
        for pid in "${PIDS[@]}"; do
            wait "$pid" || FAILED=$((FAILED + 1))
        done
        PIDS=()
        RUNNING=0
    fi
done

# Wait for remaining
for pid in "${PIDS[@]}"; do
    wait "$pid" || FAILED=$((FAILED + 1))
done

echo ""
if [ $FAILED -gt 0 ]; then
    echo "❌ $FAILED shard plan(s) failed. Check /tmp/shard-*-plan.log for details."
    exit 1
else
    echo "✅ All $FILE_COUNT shard plans completed successfully for $ENVIRONMENT environment"
fi
