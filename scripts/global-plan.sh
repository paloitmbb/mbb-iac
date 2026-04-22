#!/bin/bash
set -e

# =============================================================================
# Run Terraform plan for the global state
# =============================================================================
# Usage: ./scripts/global-plan.sh [environment]
# =============================================================================

ENVIRONMENT=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Running Terraform plan for global state (environment: $ENVIRONMENT)"

cd "$PROJECT_ROOT/global"

terraform plan \
    -var-file="$PROJECT_ROOT/environments/$ENVIRONMENT/terraform.tfvars" \
    -lock=false \
    -out="$PROJECT_ROOT/environments/$ENVIRONMENT/global-tfplan"

echo "✅ Global plan completed for $ENVIRONMENT environment"
echo "Review the plan above. To apply, run: ./scripts/global-apply.sh $ENVIRONMENT"
