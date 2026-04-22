#!/bin/bash
set -euo pipefail

# =============================================================================
# Discover all shards from data/repositories.yaml and plan each in parallel
# =============================================================================
# Usage: ./scripts/shard-plan-all.sh [environment] [max-parallel]
# Example: ./scripts/shard-plan-all.sh dev 5
# =============================================================================

ENVIRONMENT=${1:-dev}
MAX_PARALLEL=${2:-5}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$PROJECT_ROOT/data"

echo "Discovering shards from $DATA_DIR/repositories*.yaml..."

# Extract unique shard IDs from ALL repository YAML files
SHARD_IDS=$(python3 -c "
import yaml, re, glob, os

data_dir = '$DATA_DIR'
files = sorted(glob.glob(os.path.join(data_dir, 'repositories*.yaml')))
shards = set()
for fpath in files:
    with open(fpath) as f:
        data = yaml.safe_load(f) or {}
    for repo in data.get('repositories', []):
        for t in repo.get('topics', []):
            m = re.match(r'^state-group-(\d{3})$', t)
            if m:
                shards.add(m.group(1))
for s in sorted(shards):
    print(s)
")

if [ -z "$SHARD_IDS" ]; then
    echo "No shards found. Run ./scripts/assign-state-groups.sh first."
    exit 1
fi

SHARD_COUNT=$(echo "$SHARD_IDS" | wc -l | tr -d ' ')
echo "Found $SHARD_COUNT shard(s): $(echo $SHARD_IDS | tr '\n' ' ')"

# Run plans in parallel (up to MAX_PARALLEL at a time)
echo ""
echo "Planning all shards (max $MAX_PARALLEL parallel)..."
PIDS=()
RUNNING=0
FAILED=0

for SHARD_ID in $SHARD_IDS; do
    echo "  → Starting plan for shard $SHARD_ID..."
    (
        cd "$PROJECT_ROOT/shards"
        # Init with shard-specific state key (reconfigure to avoid prompt)
        terraform init -reconfigure \
            -backend-config="$PROJECT_ROOT/environments/$ENVIRONMENT/backend.tfvars" \
            -backend-config="key=github-shard-${SHARD_ID}.terraform.tfstate" \
            > /dev/null 2>&1

        ORG_NAME=$(python3 -c "
import re
with open('$PROJECT_ROOT/environments/$ENVIRONMENT/terraform.tfvars') as f:
    m = re.search(r'name\s*=\s*\"([^\"]+)\"', f.read())
    print(m.group(1) if m else 'unknown')
")
        terraform plan \
            -var="shard_id=$SHARD_ID" \
            -var="organization_name=$ORG_NAME" \
            -lock=false \
            -out="$PROJECT_ROOT/environments/$ENVIRONMENT/shard-${SHARD_ID}-tfplan" \
            > "/tmp/shard-${SHARD_ID}-plan.log" 2>&1
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
    echo "✅ All $SHARD_COUNT shard plans completed successfully for $ENVIRONMENT environment"
fi
