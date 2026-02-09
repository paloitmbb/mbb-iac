#!/bin/bash
set -e

# Import existing repositories into Terraform state
# Usage: ./scripts/import-repos.sh [environment]

ENVIRONMENT=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

echo "Importing existing repositories into Terraform state for environment: $ENVIRONMENT"

# Set HTTP backend password from GITHUB_TOKEN if not already set
if [ -z "$TF_HTTP_PASSWORD" ] && [ -n "$GITHUB_TOKEN" ]; then
    export TF_HTTP_PASSWORD="$GITHUB_TOKEN"
fi

# Import each repository
echo "Importing mbb-api-gateway..."
terraform import -lock=false -var-file="environments/$ENVIRONMENT/terraform.tfvars" \
  'module.github_repositories["mbb-api-gateway"].github_repository.this' \
  mbb-api-gateway || echo "Already imported or failed"

echo "Importing mbb-mobile-app..."
terraform import -lock=false -var-file="environments/$ENVIRONMENT/terraform.tfvars" \
  'module.github_repositories["mbb-mobile-app"].github_repository.this' \
  mbb-mobile-app || echo "Already imported or failed"

echo "Importing mbb-web-portal..."
terraform import -lock=false -var-file="environments/$ENVIRONMENT/terraform.tfvars" \
  'module.github_repositories["mbb-web-portal"].github_repository.this' \
  mbb-web-portal || echo "Already imported or failed"

echo "✅ Repository import completed for $ENVIRONMENT environment"
echo "Now you can run: ./scripts/apply.sh $ENVIRONMENT"
