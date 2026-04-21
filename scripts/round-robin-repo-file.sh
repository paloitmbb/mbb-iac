#!/bin/bash
set -euo pipefail

# =============================================================================
# Round-Robin Repository YAML File Balancer
# =============================================================================
# Usage: ./scripts/round-robin-repo-file.sh
#
# Determines which data/repositories*.yaml file should receive a new repository
# entry, using a round-robin strategy that distributes repos evenly across files.
#
# Environment variables:
#   REPO_DATA_FILE_COUNT  — Target number of YAML files (default: 50).
#                           Override in CI pipelines for repo creation / migration.
#
# Algorithm:
#   1. Scan all data/repositories*.yaml files and count repos in each.
#   2. If the number of files is LESS than REPO_DATA_FILE_COUNT:
#      → Create a new file and output its path (new file = lowest count = 0).
#   3. If the number of files is >= REPO_DATA_FILE_COUNT:
#      → Find the existing file with the lowest repo count and output its path.
#
# This is a pure helper — it only prints the chosen file path to stdout.
# It does NOT modify any files.
#
# File naming convention:
#   data/repositories.yaml       — primary file (file 001, always exists)
#   data/repositories-002.yaml   — second file
#   data/repositories-003.yaml   — third file, etc.
#
# NOTE: YAML file splitting is INDEPENDENT of state-group shard assignments.
# A repo's file location has no bearing on which Terraform state manages it.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$PROJECT_ROOT/data"

# Target number of YAML data files (overridable via env var)
TARGET_FILE_COUNT="${REPO_DATA_FILE_COUNT:-50}"

python3 - "$DATA_DIR" "$TARGET_FILE_COUNT" << 'PYEOF'
import sys, os, re, glob

import yaml

data_dir = sys.argv[1]
target_file_count = int(sys.argv[2])

# ── Discover existing repository YAML files ──────────────────────────
pattern = os.path.join(data_dir, 'repositories*.yaml')
files = sorted(glob.glob(pattern))

if not files:
    # No files at all — use the primary file
    print(os.path.join(data_dir, 'repositories.yaml'))
    sys.exit(0)

# ── Count repos in each file ─────────────────────────────────────────
file_counts = {}
for fpath in files:
    with open(fpath) as f:
        data = yaml.safe_load(f) or {}
    repos = data.get('repositories', [])
    file_counts[fpath] = len(repos)

current_file_count = len(files)

# ── File numbering helpers ────────────────────────────────────────────
def file_number(fpath):
    """Extract NNN from repositories-NNN.yaml, or 1 for the primary file."""
    basename = os.path.basename(fpath)
    m = re.match(r'repositories-(\d{3})\.yaml$', basename)
    if m:
        return int(m.group(1))
    return 1  # primary file = 001

existing_nums = sorted(set(file_number(f) for f in files))
next_num = max(existing_nums) + 1

# ── Round-robin balancing ─────────────────────────────────────────────
if current_file_count < target_file_count:
    # Create a new file — it has 0 repos, so it's the "lowest"
    new_name = f"repositories-{next_num:03d}.yaml"
    chosen = os.path.join(data_dir, new_name)
else:
    # Pick the file with the lowest repo count
    chosen = min(file_counts, key=file_counts.get)

# Output the chosen file path (absolute)
print(chosen)
PYEOF
