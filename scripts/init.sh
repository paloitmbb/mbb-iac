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

echo "Using Azure Storage backend"

# Check for Azure authentication
if [ -z "$ARM_ACCESS_KEY" ] && [ -z "$ARM_SAS_TOKEN" ] && [ -z "$ARM_CLIENT_ID" ]; then
    echo "⚠️  Warning: No Azure authentication detected"
    echo "   Please ensure one of the following is set:"
    echo "   - ARM_ACCESS_KEY (Storage Account Access Key)"
    echo "   - ARM_SAS_TOKEN (SAS Token)"
    echo "   - ARM_CLIENT_ID + ARM_TENANT_ID + ARM_SUBSCRIPTION_ID (OIDC/Service Principal)"
    echo "   - Or authenticate via Azure CLI (az login)"
else
    echo "✓ Azure authentication detected"
fi

terraform init -backend-config="environments/$ENVIRONMENT/backend.tfvars"

echo "✅ Terraform initialized successfully for $ENVIRONMENT environment"
