#!/bin/bash
set -e

# Terraform Apply Script
# Usage: ./scripts/apply.sh [environment]

ENVIRONMENT=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Applying Terraform changes for environment: $ENVIRONMENT"

cd "$PROJECT_ROOT"

if [ ! -f "environments/$ENVIRONMENT/tfplan" ]; then
    echo "Error: tfplan not found. Run ./scripts/plan.sh $ENVIRONMENT first"
    exit 1
fi

# Confirmation for production
if [ "$ENVIRONMENT" == "production" ]; then
    read -p "⚠️  You are about to apply changes to PRODUCTION. Are you sure? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Apply cancelled"
        exit 0
    fi
fi

# Run terraform apply
terraform apply -lock=false "environments/$ENVIRONMENT/tfplan"

rm -f "environments/$ENVIRONMENT/tfplan"

echo "✅ Terraform apply completed for $ENVIRONMENT environment"
