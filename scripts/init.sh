#!/bin/bash
set -e

# Terraform Init Script
# Usage: ./scripts/init.sh [environment]

ENVIRONMENT=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Initializing Terraform for environment: $ENVIRONMENT"

# Stay in project root
cd "$PROJECT_ROOT"

if [ ! -f "environments/$ENVIRONMENT/terraform.tfvars" ]; then
    echo "Error: terraform.tfvars not found in environments/$ENVIRONMENT"
    exit 1
fi

if [ ! -f "environments/$ENVIRONMENT/backend.tfvars" ]; then
    echo "Error: backend.tfvars not found in environments/$ENVIRONMENT"
    exit 1
fi

# Set HTTP backend password from GITHUB_TOKEN if not already set
if [ -z "$TF_HTTP_PASSWORD" ] && [ -n "$GITHUB_TOKEN" ]; then
    export TF_HTTP_PASSWORD="$GITHUB_TOKEN"
    echo "Using GITHUB_TOKEN for HTTP backend authentication"
fi

if [ -z "$TF_HTTP_PASSWORD" ]; then
    echo "⚠️  Warning: Neither TF_HTTP_PASSWORD nor GITHUB_TOKEN is set"
    echo "   Backend authentication may fail"
fi

terraform init -backend-config="environments/$ENVIRONMENT/backend.tfvars"

echo "✅ Terraform initialized successfully for $ENVIRONMENT environment"
