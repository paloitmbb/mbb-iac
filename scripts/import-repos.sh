#!/bin/bash
set -euo pipefail

# Dynamically import repositories defined in data/repositories.yaml
# that are not yet present in Terraform state.
# Usage: ./scripts/import-repos.sh [environment]

ENVIRONMENT=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

echo "🔍 Detecting repositories to import for environment: $ENVIRONMENT"

# Ensure terraform is initialized
if [ ! -d .terraform ]; then
  echo "⚠️  Terraform not initialized. Run: ./scripts/init.sh $ENVIRONMENT"
  exit 1
fi

# Get repo names defined in YAML
YAML_REPOS=$(python3 -c "
import yaml
with open('data/repositories.yaml') as f:
    data = yaml.safe_load(f) or {'repositories': []}
for repo in data.get('repositories', []):
    print(repo['name'])
")

# Get repo keys already in Terraform state
STATE_LIST=$(terraform state list 2>/dev/null || echo "")
STATE_REPOS=$(echo "$STATE_LIST" | sed -n 's/^module\.github_repositories\["\([^"]*\)"\]\.github_repository\.this$/\1/p' | sort -u)

# Compute repos needing import
IMPORTED=0
FAILED=0

while IFS= read -r REPO_NAME; do
  [ -z "$REPO_NAME" ] && continue

  # Skip if already in state
  if echo "$STATE_REPOS" | grep -qxF "$REPO_NAME" 2>/dev/null; then
    continue
  fi

  echo "📥 Importing $REPO_NAME..."
  if terraform import -var-file="environments/$ENVIRONMENT/terraform.tfvars" \
    "module.github_repositories[\"${REPO_NAME}\"].github_repository.this" \
    "$REPO_NAME" 2>&1; then
    echo "  ✅ Successfully imported $REPO_NAME"
    IMPORTED=$((IMPORTED + 1))
  else
    echo "  ❌ Failed to import $REPO_NAME"
    FAILED=$((FAILED + 1))
  fi
done <<< "$YAML_REPOS"

if [ "$IMPORTED" -eq 0 ] && [ "$FAILED" -eq 0 ]; then
  echo "✅ All repositories are already in Terraform state"
else
  echo ""
  echo "✅ Import completed for $ENVIRONMENT environment: $IMPORTED imported, $FAILED failed"
  echo "Now you can run: ./scripts/apply.sh $ENVIRONMENT"
fi
