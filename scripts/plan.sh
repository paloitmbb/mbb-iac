#!/bin/bash
set -e

# Terraform Plan Script
# Usage: ./scripts/plan.sh [environment]

ENVIRONMENT=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Running Terraform plan for environment: $ENVIRONMENT"

cd "$PROJECT_ROOT"

# Set HTTP backend password from GITHUB_TOKEN if not already set
if [ -z "$TF_HTTP_PASSWORD" ] && [ -n "$GITHUB_TOKEN" ]; then
    export TF_HTTP_PASSWORD="$GITHUB_TOKEN"
fi

terraform plan -var-file="environments/$ENVIRONMENT/terraform.tfvars" -lock=false -out="environments/$ENVIRONMENT/tfplan"

echo "✅ Terraform plan completed for $ENVIRONMENT environment"
echo "Review the plan above. To apply, run: ./scripts/apply.sh $ENVIRONMENT"
