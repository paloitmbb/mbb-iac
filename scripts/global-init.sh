#!/bin/bash
set -e

# =============================================================================
# Initialize Terraform for the global state
# =============================================================================
# Usage: ./scripts/global-init.sh [environment]
# =============================================================================

ENVIRONMENT=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Initializing global Terraform state for environment: $ENVIRONMENT"

cd "$PROJECT_ROOT/global"

if [ ! -f "$PROJECT_ROOT/environments/$ENVIRONMENT/backend.tfvars" ]; then
    echo "Error: backend.tfvars not found in environments/$ENVIRONMENT"
    exit 1
fi

# Check for Azure authentication
if [ -z "${ARM_ACCESS_KEY:-}" ] && [ -z "${ARM_SAS_TOKEN:-}" ] && [ -z "${ARM_CLIENT_ID:-}" ]; then
    echo "⚠️  Warning: No Azure authentication detected"
else
    echo "✓ Azure authentication detected"
fi

terraform init \
    -backend-config="$PROJECT_ROOT/environments/$ENVIRONMENT/backend.tfvars" \
    -backend-config="key=github-global.terraform.tfstate"

echo "✅ Global state initialized successfully for $ENVIRONMENT environment"
