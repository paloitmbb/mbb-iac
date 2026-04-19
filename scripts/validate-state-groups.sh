#!/bin/bash
set -euo pipefail

# =============================================================================
# Validate that every repository in data/repositories.yaml has exactly one
# state-group-NNN topic and that no shard exceeds the maximum size.
# =============================================================================
# Usage: ./scripts/validate-state-groups.sh [max-per-shard]
# Exit code 0 = pass, 1 = fail
# =============================================================================

MAX_PER_SHARD=${1:-50}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REPOS_FILE="$PROJECT_ROOT/data/repositories.yaml"

if [ ! -f "$REPOS_FILE" ]; then
    echo "Error: $REPOS_FILE not found"
    exit 1
fi

python3 - "$REPOS_FILE" "$MAX_PER_SHARD" << 'PYEOF'
import yaml, sys, re

repos_file = sys.argv[1]
max_per_shard = int(sys.argv[2])

with open(repos_file) as f:
    data = yaml.safe_load(f)

STATE_GROUP_RE = re.compile(r'^state-group-(\d{3})$')
errors = []
group_counts = {}

for repo in data.get('repositories', []):
    name = repo.get('name', '<unknown>')
    topics = repo.get('topics', [])
    groups = [t for t in topics if STATE_GROUP_RE.match(t)]

    if len(groups) == 0:
        errors.append(f"❌ {name}: missing state-group topic")
    elif len(groups) > 1:
        errors.append(f"❌ {name}: multiple state-group topics: {groups}")
    else:
        g = int(STATE_GROUP_RE.match(groups[0]).group(1))
        group_counts[g] = group_counts.get(g, 0) + 1

# Check shard sizes
for g, count in sorted(group_counts.items()):
    if count > max_per_shard:
        errors.append(f"⚠️  state-group-{g:03d} has {count} repos (max {max_per_shard})")
    print(f"  state-group-{g:03d}: {count} repo(s)")

if errors:
    print()
    for e in errors:
        print(e)
    print(f"\n❌ Validation failed with {len(errors)} issue(s)")
    sys.exit(1)
else:
    total = sum(group_counts.values())
    print(f"\n✅ All {total} repositories have valid state-group topics across {len(group_counts)} shard(s)")
PYEOF
