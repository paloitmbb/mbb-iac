#!/usr/bin/env bash
# discover-repos.sh — Discover all repos in a GitHub org and classify by tier topic
# Usage: ./scripts/discover-repos.sh
#
# Required env vars:
#   GH_BACKUP_TOKEN  — GitHub PAT with repo + read:org scopes
#   GITHUB_ORG       — GitHub organisation name
#
# Output: writes repo-tiers.json to the current directory

set -euo pipefail

: "${GH_BACKUP_TOKEN:?Environment variable GH_BACKUP_TOKEN is required}"
: "${GITHUB_ORG:?Environment variable GITHUB_ORG is required}"

API_BASE="https://api.github.com"
AUTH_HEADER="Authorization: token ${GH_BACKUP_TOKEN}"
ACCEPT_HEADER="Accept: application/vnd.github.v3+json"

# Initialise tier arrays as temporary files (portable across bash versions)
tier1_file=$(mktemp)
tier2_file=$(mktemp)
tier3_file=$(mktemp)
tier4_file=$(mktemp)
trap 'rm -f "$tier1_file" "$tier2_file" "$tier3_file" "$tier4_file"' EXIT

# --- Paginate through all org repos ---
page=1
per_page=100

echo "Discovering repos for organisation: ${GITHUB_ORG}"

while true; do
  response=$(curl -sf \
    -H "${AUTH_HEADER}" \
    -H "${ACCEPT_HEADER}" \
    "${API_BASE}/orgs/${GITHUB_ORG}/repos?per_page=${per_page}&page=${page}&type=all")

  repo_count=$(echo "$response" | jq 'length')
  if [[ "$repo_count" -eq 0 ]]; then
    break
  fi

  # Extract repo names (exclude archived repos)
  repo_names=$(echo "$response" | jq -r '.[] | select(.archived == false) | .name')

  for repo in $repo_names; do
    # Fetch topics for this repo
    topics_response=$(curl -sf \
      -H "${AUTH_HEADER}" \
      -H "${ACCEPT_HEADER}" \
      "${API_BASE}/repos/${GITHUB_ORG}/${repo}/topics")

    topics=$(echo "$topics_response" | jq -r '.names[]' 2>/dev/null || echo "")

    # Classify by tier topic (GitHub normalises topics to lowercase with hyphens)
    tier_found=""
    for topic in $topics; do
      case "$topic" in
        tier-1) tier_found="1"; break ;;
        tier-2) tier_found="2"; break ;;
        tier-3) tier_found="3"; break ;;
        tier-4) tier_found="4"; break ;;
      esac
    done

    case "$tier_found" in
      1) echo "$repo" >> "$tier1_file" ;;
      2) echo "$repo" >> "$tier2_file" ;;
      3) echo "$repo" >> "$tier3_file" ;;
      *)
        # Tier 4 or no tier → default (monthly)
        echo "$repo" >> "$tier4_file"
        ;;
    esac

    echo "  ${repo} → tier-${tier_found:-default}"
  done

  # If we got fewer repos than per_page, we've reached the last page
  if [[ "$repo_count" -lt "$per_page" ]]; then
    break
  fi

  page=$((page + 1))
done

# --- Build JSON output ---
to_json_array() {
  local file="$1"
  if [[ -s "$file" ]]; then
    jq -R -s 'split("\n") | map(select(length > 0))' < "$file"
  else
    echo "[]"
  fi
}

jq -n \
  --argjson tier1 "$(to_json_array "$tier1_file")" \
  --argjson tier2 "$(to_json_array "$tier2_file")" \
  --argjson tier3 "$(to_json_array "$tier3_file")" \
  --argjson tier4_default "$(to_json_array "$tier4_file")" \
  '{tier1: $tier1, tier2: $tier2, tier3: $tier3, tier4_default: $tier4_default}' \
  > repo-tiers.json

echo ""
echo "Discovery complete. Results written to repo-tiers.json:"
cat repo-tiers.json
