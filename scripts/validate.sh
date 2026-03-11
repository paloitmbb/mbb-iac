#!/bin/bash
set -e

# Terraform Validate Script
# Usage: ./scripts/validate.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Validating Terraform configuration..."

cd "$PROJECT_ROOT"

# Format check
echo "Checking Terraform formatting..."
terraform fmt -check -recursive

# Validate each environment
for ENV in dev production; do
    echo "Validating $ENV environment..."
    cd "$PROJECT_ROOT/environments/$ENV"
    terraform init -backend=false > /dev/null 2>&1
    terraform validate
done

cd "$PROJECT_ROOT"

echo "✅ All Terraform configurations are valid"
