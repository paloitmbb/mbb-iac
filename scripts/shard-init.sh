#!/bin/bash
set -e

# =============================================================================
# Initialize Terraform for a specific shard
# =============================================================================
# Usage: ./scripts/shard-init.sh <shard_id> [environment]
# Example: ./scripts/shard-init.sh 001 dev
# =============================================================================

if [ -z "$1" ]; then
    echo "Usage: ./scripts/shard-init.sh <shard_id> [environment]"
    echo "Example: ./scripts/shard-init.sh 001 dev"
    exit 1
fi

SHARD_ID=$1
ENVIRONMENT=${2:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Initializing shard $SHARD_ID for environment: $ENVIRONMENT"

cd "$PROJECT_ROOT/shards"

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
    -backend-config="key=github-shard-${SHARD_ID}.terraform.tfstate"

echo "✅ Shard $SHARD_ID initialized successfully for $ENVIRONMENT environment"
