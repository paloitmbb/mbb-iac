#!/bin/bash
set -euo pipefail

# =============================================================================
# Auto-assign state-group-NNN topics to repositories without one
# =============================================================================
# Usage: ./scripts/assign-state-groups.sh [max-per-shard]
#
# Parses ALL data/repositories*.yaml files, finds repos lacking a
# state-group-* topic, and assigns them to the first group with fewer than
# <max-per-shard> members (default: 50), or creates a new group.
#
# Supports split YAML files: data/repositories.yaml, data/repositories-002.yaml, etc.
# Each file is updated in-place so only the files containing unassigned repos change.
#
# Rules:
#   - Only ADDS topics; never moves repos between groups.
#   - state-group-NNN topics are zero-padded to 3 digits.
#   - Archived repos keep their group assignment.
# =============================================================================

MAX_PER_SHARD=${1:-50}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$PROJECT_ROOT/data"

# Find all repository YAML files
REPO_FILES=$(find "$DATA_DIR" -maxdepth 1 -name 'repositories*.yaml' | sort)

if [ -z "$REPO_FILES" ]; then
    echo "Error: No repositories*.yaml files found in $DATA_DIR"
    exit 1
fi

echo "Scanning repository YAML files for state-group assignment:"
echo "$REPO_FILES" | while read -r f; do echo "  $(basename "$f")"; done
echo ""

# First pass: count existing group assignments across ALL files using PyYAML
GLOBAL_GROUP_COUNTS=$(python3 -c "
import yaml, re, json, glob, os

data_dir = '$DATA_DIR'
files = sorted(glob.glob(os.path.join(data_dir, 'repositories*.yaml')))
STATE_GROUP_RE = re.compile(r'^state-group-(\d{3})$')
group_counts = {}

for fpath in files:
    with open(fpath) as f:
        data = yaml.safe_load(f) or {}
    for repo in data.get('repositories', []):
        for t in repo.get('topics', []):
            m = STATE_GROUP_RE.match(t)
            if m:
                g = int(m.group(1))
                group_counts[g] = group_counts.get(g, 0) + 1
print(json.dumps(group_counts))
")

# Process each file independently (in-place edits)
for REPOS_FILE in $REPO_FILES; do
    python3 - "$REPOS_FILE" "$MAX_PER_SHARD" "$GLOBAL_GROUP_COUNTS" << 'PYEOF'
import sys, re, json

repos_file = sys.argv[1]
max_per_shard = int(sys.argv[2])
group_counts = {int(k): v for k, v in json.loads(sys.argv[3]).items()}

with open(repos_file, 'r') as f:
    content = f.read()

# ── helpers ──────────────────────────────────────────────────────────
STATE_GROUP_RE = re.compile(r'state-group-(\d{3})')

def extract_repo_blocks(text):
    """Yield (start, end, name, topics_line_indices, has_state_group, group_num) for each repo."""
    lines = text.split('\n')
    repos = []
    i = 0
    while i < len(lines):
        # Match "  - name: <repo-name>"
        m = re.match(r'^  - name:\s+(.+)', lines[i])
        if m:
            repo_start = i
            repo_name = m.group(1).strip().strip('"').strip("'")
            i += 1
            topics_start = None
            topics_end = None
            has_state_group = False
            group_num = None
            in_topics = False
            # Read until next repo or end of file
            while i < len(lines):
                line = lines[i]
                # Next repo block
                if re.match(r'^  - name:\s+', line):
                    break
                # Inline topics: topics: ["a", "b"]
                if re.match(r'^\s+topics:\s*\[', line):
                    topics_start = i
                    topics_end = i
                    sg = STATE_GROUP_RE.search(line)
                    if sg:
                        has_state_group = True
                        group_num = int(sg.group(1))
                    in_topics = False
                    i += 1
                    continue
                # Block topics start: topics:
                if re.match(r'^\s+topics:\s*$', line):
                    topics_start = i
                    in_topics = True
                    i += 1
                    continue
                if in_topics:
                    if re.match(r'^\s+- ', line):
                        topics_end = i
                        sg = STATE_GROUP_RE.search(line)
                        if sg:
                            has_state_group = True
                            group_num = int(sg.group(1))
                        i += 1
                        continue
                    else:
                        in_topics = False
                i += 1
            repos.append({
                'start': repo_start,
                'end': i,
                'name': repo_name,
                'topics_start': topics_start,
                'topics_end': topics_end,
                'has_state_group': has_state_group,
                'group_num': group_num,
            })
        else:
            i += 1
    return repos, lines

repos, lines = extract_repo_blocks(content)

unassigned = [r for r in repos if not r['has_state_group']]
if not unassigned:
    import os
    print(f"  {os.path.basename(repos_file)}: ✅ all repos assigned")
    sys.exit(0)

import os
print(f"  {os.path.basename(repos_file)}: {len(unassigned)} repo(s) to assign")

# ── assign groups (using global counts shared across all files) ──────
def next_available_group():
    """Return the first group number with room, or create a new one."""
    for g in sorted(group_counts.keys()):
        if group_counts[g] < max_per_shard:
            return g
    # All full or none exist — create next
    return max(group_counts.keys(), default=0) + 1

# Build insertions: list of (line_index, topic_text, mode) to inject
insertions = []
for r in unassigned:
    g = next_available_group()
    group_counts[g] = group_counts.get(g, 0) + 1
    topic_value = f"state-group-{g:03d}"
    print(f"    → {r['name']} assigned to {topic_value}")

    if r['topics_start'] is None:
        # No topics key at all — insert before the repo's end
        insert_line = r['end']
        insertions.append((insert_line, f"    topics:\n      - {topic_value}", 'insert'))
    else:
        line = lines[r['topics_start']]
        # Inline format: topics: ["a", "b"]
        inline_match = re.match(r'^(\s+topics:\s*)\[(.*)]\s*$', line)
        if inline_match:
            prefix = inline_match.group(1)
            existing = inline_match.group(2).strip()
            if existing:
                new_line = f'{prefix}[{existing}, "{topic_value}"]'
            else:
                new_line = f'{prefix}["{topic_value}"]'
            insertions.append((r['topics_start'], new_line, 'replace'))
        else:
            # Block format — append after last topic item
            if r['topics_end'] is not None and r['topics_end'] >= r['topics_start']:
                insert_after = r['topics_end']
                indent = "      "
                if r['topics_end'] > r['topics_start']:
                    m2 = re.match(r'^(\s+)- ', lines[r['topics_end']])
                    if m2:
                        indent = m2.group(1)
                insertions.append((insert_after + 1, f"{indent}- {topic_value}", 'insert'))
            else:
                # topics: with no items — add first item
                indent = "      "
                insertions.append((r['topics_start'] + 1, f"{indent}- {topic_value}", 'insert'))

# ── apply changes (reverse order to preserve indices) ────────────────
insertions.sort(key=lambda x: x[0], reverse=True)
for item in insertions:
    idx, text, mode = item
    if mode == 'replace':
        lines[idx] = text
    elif mode == 'insert':
        lines.insert(idx, text)

with open(repos_file, 'w') as f:
    f.write('\n'.join(lines))

print(f"    ✅ Updated {os.path.basename(repos_file)}")
PYEOF
done

echo ""
echo "✅ State-group assignment complete across all repository YAML files"
