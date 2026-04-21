#!/bin/bash
set -e

# =============================================================================
# Initialize Terraform for a specific shard (YAML file-based)
# =============================================================================
# Usage: ./scripts/shard-init.sh <repositories_file> [environment]
# Example: ./scripts/shard-init.sh repositories.yaml dev
#          ./scripts/shard-init.sh repositories-002.yaml production
# =============================================================================

if [ -z "$1" ]; then
    echo "Usage: ./scripts/shard-init.sh <repositories_file> [environment]"
    echo "Example: ./scripts/shard-init.sh repositories.yaml dev"
    exit 1
fi

REPOS_FILE=$1
ENVIRONMENT=${2:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Derive state key from filename: repositories.yaml → github-repos-repositories
# repositories-002.yaml → github-repos-repositories-002
STATE_KEY_BASE=$(echo "$REPOS_FILE" | sed 's/\.yaml$//')
STATE_KEY="github-repos-${STATE_KEY_BASE}.terraform.tfstate"

echo "Initializing shard for $REPOS_FILE (environment: $ENVIRONMENT)"
echo "  State key: $STATE_KEY"

cd "$PROJECT_ROOT/shards"

if [ ! -f "$PROJECT_ROOT/environments/$ENVIRONMENT/backend.tfvars" ]; then
    echo "Error: backend.tfvars not found in environments/$ENVIRONMENT"
    exit 1
fi

if [ ! -f "$PROJECT_ROOT/data/$REPOS_FILE" ]; then
    echo "Error: $REPOS_FILE not found in data/"
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
    -backend-config="key=$STATE_KEY"

echo "✅ Shard for $REPOS_FILE initialized successfully for $ENVIRONMENT environment"
