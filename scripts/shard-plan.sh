#!/bin/bash
set -e

# =============================================================================
# Run Terraform plan for a specific shard
# =============================================================================
# Usage: ./scripts/shard-plan.sh <shard_id> [environment]
# Example: ./scripts/shard-plan.sh 001 dev
# =============================================================================

if [ -z "$1" ]; then
    echo "Usage: ./scripts/shard-plan.sh <shard_id> [environment]"
    echo "Example: ./scripts/shard-plan.sh 001 dev"
    exit 1
fi

SHARD_ID=$1
ENVIRONMENT=${2:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Running Terraform plan for shard $SHARD_ID (environment: $ENVIRONMENT)"

cd "$PROJECT_ROOT/shards"

terraform plan \
    -var="shard_id=$SHARD_ID" \
    -var="organization_name=$(python3 -c "
import re
with open('$PROJECT_ROOT/environments/$ENVIRONMENT/terraform.tfvars') as f:
    m = re.search(r'name\s*=\s*\"([^\"]+)\"', f.read())
    print(m.group(1) if m else 'unknown')
")" \
    -lock=false \
    -out="$PROJECT_ROOT/environments/$ENVIRONMENT/shard-${SHARD_ID}-tfplan"

echo "✅ Shard $SHARD_ID plan completed for $ENVIRONMENT environment"
echo "Review the plan above. To apply, run: ./scripts/shard-apply.sh $SHARD_ID $ENVIRONMENT"
