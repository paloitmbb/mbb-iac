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

# Set HTTP backend password from GITHUB_TOKEN if not already set
if [ -z "$TF_HTTP_PASSWORD" ] && [ -n "$GITHUB_TOKEN" ]; then
    export TF_HTTP_PASSWORD="$GITHUB_TOKEN"
fi

# Run terraform apply and handle state saving errors
if ! terraform apply -lock=false "environments/$ENVIRONMENT/tfplan"; then
    # Check if this is a state saving error
    if [ -f "errored.tfstate" ]; then
        echo "⚠️  Error saving state detected. Attempting manual state upload..."
        gh release upload state-dev errored.tfstate --clobber && \
        gh release download state-dev -p "errored.tfstate" -O terraform.tfstate && \
        gh release upload state-dev terraform.tfstate --clobber && \
        rm terraform.tfstate errored.tfstate
        echo "✅ State manually uploaded to GitHub release"
    else
        echo "❌ Terraform apply failed"
        exit 1
    fi
fi

rm -f "environments/$ENVIRONMENT/tfplan"

echo "✅ Terraform apply completed for $ENVIRONMENT environment"
