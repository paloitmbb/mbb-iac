#!/bin/bash
set -euo pipefail

# =============================================================================
# Validate that every repository across all data/repositories*.yaml files has
# exactly one state-group-NNN topic and that no shard exceeds the maximum size.
# =============================================================================
# Usage: ./scripts/validate-state-groups.sh [max-per-shard]
# Exit code 0 = pass, 1 = fail
# =============================================================================

MAX_PER_SHARD=${1:-50}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$PROJECT_ROOT/data"

python3 - "$DATA_DIR" "$MAX_PER_SHARD" << 'PYEOF'
import yaml, sys, re, glob, os

data_dir = sys.argv[1]
max_per_shard = int(sys.argv[2])

# Discover all repository YAML files
files = sorted(glob.glob(os.path.join(data_dir, 'repositories*.yaml')))
if not files:
    print("Error: No repositories*.yaml files found in", data_dir)
    sys.exit(1)

STATE_GROUP_RE = re.compile(r'^state-group-(\d{3})$')
errors = []
group_counts = {}
total_repos = 0
seen_names = {}  # name -> filename (detect duplicates across files)

for fpath in files:
    basename = os.path.basename(fpath)
    with open(fpath) as f:
        data = yaml.safe_load(f) or {}
    repos = data.get('repositories', [])
    file_count = len(repos)
    total_repos += file_count
    print(f"  {basename}: {file_count} repos")

    for repo in repos:
        name = repo.get('name', '<unknown>')
        topics = repo.get('topics', [])
        groups = [t for t in topics if STATE_GROUP_RE.match(t)]

        # Check for duplicate repo names across files
        if name in seen_names:
            errors.append(f"❌ {name}: duplicate entry (in {seen_names[name]} and {basename})")
        seen_names[name] = basename

        if len(groups) == 0:
            errors.append(f"❌ {name} ({basename}): missing state-group topic")
        elif len(groups) > 1:
            errors.append(f"❌ {name} ({basename}): multiple state-group topics: {groups}")
        else:
            g = int(STATE_GROUP_RE.match(groups[0]).group(1))
            group_counts[g] = group_counts.get(g, 0) + 1

# Check shard sizes
print()
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
    print(f"\n✅ All {total_repos} repositories have valid state-group topics across {len(group_counts)} shard(s)")
    print(f"   Spread across {len(files)} YAML file(s)")
PYEOF
