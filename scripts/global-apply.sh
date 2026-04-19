#!/bin/bash
set -e

# =============================================================================
# Run Terraform apply for the global state
# =============================================================================
# Usage: ./scripts/global-apply.sh [environment]
# =============================================================================

ENVIRONMENT=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PLAN_FILE="$PROJECT_ROOT/environments/$ENVIRONMENT/global-tfplan"

echo "Applying global Terraform changes for environment: $ENVIRONMENT"

cd "$PROJECT_ROOT/global"

if [ ! -f "$PLAN_FILE" ]; then
    echo "Error: global-tfplan not found. Run ./scripts/global-plan.sh $ENVIRONMENT first"
    exit 1
fi

# Confirmation for production
if [ "$ENVIRONMENT" == "production" ]; then
    read -p "⚠️  You are about to apply GLOBAL changes to PRODUCTION. Are you sure? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Apply cancelled"
        exit 0
    fi
fi

terraform apply -lock=false "$PLAN_FILE"
rm -f "$PLAN_FILE"

echo "✅ Global apply completed for $ENVIRONMENT environment"
