#!/bin/bash
set -e

# =============================================================================
# Run Terraform apply for a specific shard
# =============================================================================
# Usage: ./scripts/shard-apply.sh <shard_id> [environment]
# Example: ./scripts/shard-apply.sh 001 dev
# =============================================================================

if [ -z "$1" ]; then
    echo "Usage: ./scripts/shard-apply.sh <shard_id> [environment]"
    echo "Example: ./scripts/shard-apply.sh 001 dev"
    exit 1
fi

SHARD_ID=$1
ENVIRONMENT=${2:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PLAN_FILE="$PROJECT_ROOT/environments/$ENVIRONMENT/shard-${SHARD_ID}-tfplan"

echo "Applying shard $SHARD_ID Terraform changes for environment: $ENVIRONMENT"

cd "$PROJECT_ROOT/shards"

if [ ! -f "$PLAN_FILE" ]; then
    echo "Error: shard plan not found. Run ./scripts/shard-plan.sh $SHARD_ID $ENVIRONMENT first"
    exit 1
fi

# Confirmation for production
if [ "$ENVIRONMENT" == "production" ]; then
    read -p "⚠️  You are about to apply shard $SHARD_ID to PRODUCTION. Are you sure? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Apply cancelled"
        exit 0
    fi
fi

terraform apply -lock=false "$PLAN_FILE"
rm -f "$PLAN_FILE"

echo "✅ Shard $SHARD_ID apply completed for $ENVIRONMENT environment"
