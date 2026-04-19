#!/bin/bash
set -e

# =============================================================================
# Run Terraform plan for a specific shard (YAML file-based)
# =============================================================================
# Usage: ./scripts/shard-plan.sh <repositories_file> [environment]
# Example: ./scripts/shard-plan.sh repositories.yaml dev
#          ./scripts/shard-plan.sh repositories-002.yaml production
# =============================================================================

if [ -z "$1" ]; then
    echo "Usage: ./scripts/shard-plan.sh <repositories_file> [environment]"
    echo "Example: ./scripts/shard-plan.sh repositories.yaml dev"
    exit 1
fi

REPOS_FILE=$1
ENVIRONMENT=${2:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Derive a safe plan-file name from the YAML filename
PLAN_NAME=$(echo "$REPOS_FILE" | sed 's/\.yaml$//')

echo "Running Terraform plan for shard $REPOS_FILE (environment: $ENVIRONMENT)"

cd "$PROJECT_ROOT/shards"

terraform plan \
    -var="repositories_file=$REPOS_FILE" \
    -var="organization_name=$(python3 -c "
import re
with open('$PROJECT_ROOT/environments/$ENVIRONMENT/terraform.tfvars') as f:
    m = re.search(r'name\s*=\s*\"([^\"]+)\"', f.read())
    print(m.group(1) if m else 'unknown')
")" \
    -lock=false \
    -out="$PROJECT_ROOT/environments/$ENVIRONMENT/shard-${PLAN_NAME}-tfplan"

echo "✅ Shard plan for $REPOS_FILE completed for $ENVIRONMENT environment"
echo "Review the plan above. To apply, run: ./scripts/shard-apply.sh $REPOS_FILE $ENVIRONMENT"
