#!/bin/bash
set -e

# =============================================================================
# Run Terraform apply for a specific shard (YAML file-based)
# =============================================================================
# Usage: ./scripts/shard-apply.sh <repositories_file> [environment]
# Example: ./scripts/shard-apply.sh repositories.yaml dev
#          ./scripts/shard-apply.sh repositories-002.yaml production
# =============================================================================

if [ -z "$1" ]; then
    echo "Usage: ./scripts/shard-apply.sh <repositories_file> [environment]"
    echo "Example: ./scripts/shard-apply.sh repositories.yaml dev"
    exit 1
fi

REPOS_FILE=$1
ENVIRONMENT=${2:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Derive a safe plan-file name from the YAML filename
PLAN_NAME=$(echo "$REPOS_FILE" | sed 's/\.yaml$//')
PLAN_FILE="$PROJECT_ROOT/environments/$ENVIRONMENT/shard-${PLAN_NAME}-tfplan"

echo "Applying shard $REPOS_FILE Terraform changes for environment: $ENVIRONMENT"

cd "$PROJECT_ROOT/shards"

if [ ! -f "$PLAN_FILE" ]; then
    echo "Error: shard plan not found. Run ./scripts/shard-plan.sh $REPOS_FILE $ENVIRONMENT first"
    exit 1
fi

# Confirmation for production
if [ "$ENVIRONMENT" == "production" ]; then
    read -p "⚠️  You are about to apply shard $REPOS_FILE to PRODUCTION. Are you sure? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Apply cancelled"
        exit 0
    fi
fi

terraform apply -lock=false "$PLAN_FILE"
rm -f "$PLAN_FILE"

echo "✅ Shard $REPOS_FILE apply completed for $ENVIRONMENT environment"
