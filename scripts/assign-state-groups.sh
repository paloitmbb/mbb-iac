#!/bin/bash
set -euo pipefail

# =============================================================================
# Auto-assign state-group-NNN topics to repositories without one
# =============================================================================
# Usage: ./scripts/assign-state-groups.sh [max-per-shard]
#
# Parses data/repositories.yaml, finds repos lacking a state-group-* topic,
# and assigns them to the first group with fewer than <max-per-shard> members
# (default: 50), or creates a new group.
#
# Rules:
#   - Only ADDS topics; never moves repos between groups.
#   - state-group-NNN topics are zero-padded to 3 digits.
#   - Archived repos keep their group assignment.
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
import sys
import re

repos_file = sys.argv[1]
max_per_shard = int(sys.argv[2])

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

# ── compute group fill levels ────────────────────────────────────────
group_counts = {}  # group_num -> count
for r in repos:
    if r['has_state_group']:
        g = r['group_num']
        group_counts[g] = group_counts.get(g, 0) + 1

unassigned = [r for r in repos if not r['has_state_group']]
if not unassigned:
    print("✅ All repositories already have a state-group topic")
    sys.exit(0)

print(f"Found {len(unassigned)} repo(s) without a state-group topic")

# ── assign groups ────────────────────────────────────────────────────
def next_available_group():
    """Return the first group number with room, or create a new one."""
    for g in sorted(group_counts.keys()):
        if group_counts[g] < max_per_shard:
            return g
    # All full or none exist — create next
    return max(group_counts.keys(), default=0) + 1

# Build insertions: list of (line_index, topic_text) to inject
# We process in reverse order so line indices remain stable.
insertions = []
for r in unassigned:
    g = next_available_group()
    group_counts[g] = group_counts.get(g, 0) + 1
    topic_value = f"state-group-{g:03d}"
    print(f"  → {r['name']} assigned to {topic_value}")

    if r['topics_start'] is None:
        # No topics key at all — should not happen per schema, but handle it
        # Insert before the repo's end
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
                # Detect indentation from existing topic items
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
# Sort by line number descending
insertions.sort(key=lambda x: x[0], reverse=True)
for item in insertions:
    idx, text, mode = item
    if mode == 'replace':
        lines[idx] = text
    elif mode == 'insert':
        lines.insert(idx, text)

with open(repos_file, 'w') as f:
    f.write('\n'.join(lines))

print(f"✅ Assigned state-group topics to {len(unassigned)} repositories")
PYEOF
