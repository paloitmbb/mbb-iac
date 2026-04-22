#!/bin/bash
set -euo pipefail

# =============================================================================
# Split repositories YAML files for merge-conflict reduction
# =============================================================================
# Usage: ./scripts/split-repositories-yaml.sh [max-repos-per-file]
#
# When any repository YAML file in data/ exceeds the threshold (default: 200),
# this script redistributes repos across files so each file has at most
# <max-repos-per-file> entries.
#
# NOTE: For new repos, prefer using the round-robin balancer instead:
#   scripts/round-robin-repo-file.sh
# The round-robin script distributes new repos one-at-a-time to the file with
# the lowest count, and is used by the repo creation and onboarding workflows.
# This split script is for retroactively rebalancing existing large files.
#
# File naming convention:
#   data/repositories.yaml       — primary file (always exists)
#   data/repositories-002.yaml   — second file
#   data/repositories-003.yaml   — third file, etc.
#
# Rules:
#   - Each YAML file maps directly to its own Terraform state.
#     Moving repos between files changes which state manages them.
#   - Repos are NOT moved between existing files unless a file exceeds the threshold.
#   - When a file overflows, the excess repos are moved to a new file
#     (a new Terraform state will be created automatically on next apply).
#   - New repos (added by the creation workflow) go to the file with the most room.
#   - The script preserves the YAML structure (header comments, formatting).
# =============================================================================

MAX_PER_FILE=${1:-200}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$PROJECT_ROOT/data"

python3 - "$DATA_DIR" "$MAX_PER_FILE" << 'PYEOF'
import sys, os, re, glob

import yaml

data_dir = sys.argv[1]
max_per_file = int(sys.argv[2])

HEADER_TEMPLATE = """---
# Repository configurations loaded dynamically by Terraform
# Split file {file_num} — created automatically by round-robin balancing.
# Each YAML file maps to its own Terraform state.

repositories:
"""

# ── Discover existing repository YAML files ──────────────────────────
pattern = os.path.join(data_dir, 'repositories*.yaml')
files = sorted(glob.glob(pattern))

if not files:
    print("No repository YAML files found in", data_dir)
    sys.exit(1)

# ── Load all repos from all files, tracking which file each came from ─
file_repos = {}  # filename -> list of repo dicts
all_repos = []

for fpath in files:
    with open(fpath) as f:
        data = yaml.safe_load(f) or {}
    repos = data.get('repositories', [])
    file_repos[fpath] = repos
    all_repos.extend(repos)

total = len(all_repos)
print(f"Found {total} total repositories across {len(files)} file(s)")

# ── Check if any file exceeds the threshold ──────────────────────────
needs_split = False
for fpath, repos in file_repos.items():
    count = len(repos)
    basename = os.path.basename(fpath)
    print(f"  {basename}: {count} repos", end="")
    if count > max_per_file:
        print(f" ← exceeds threshold ({max_per_file})")
        needs_split = True
    else:
        print()

if not needs_split:
    print(f"\n✅ No files exceed {max_per_file} repos — no split needed")
    sys.exit(0)

# ── Determine existing file numbering ────────────────────────────────
# repositories.yaml = file 001 (implicit)
# repositories-NNN.yaml = file NNN
def file_number(fpath):
    basename = os.path.basename(fpath)
    m = re.match(r'repositories-(\d{3})\.yaml$', basename)
    if m:
        return int(m.group(1))
    return 1  # primary file = 001

existing_nums = sorted(set(file_number(f) for f in files))
next_num = max(existing_nums) + 1

# ── Split overflowing files ──────────────────────────────────────────
new_files = {}  # new filename -> list of repos

for fpath in list(file_repos.keys()):
    repos = file_repos[fpath]
    if len(repos) <= max_per_file:
        continue

    basename = os.path.basename(fpath)
    print(f"\n📂 Splitting {basename} ({len(repos)} repos)...")

    # Keep the first max_per_file repos in the original file
    keep = repos[:max_per_file]
    overflow = repos[max_per_file:]

    file_repos[fpath] = keep
    print(f"  Keeping {len(keep)} repos in {basename}")

    # Distribute overflow into new files of max_per_file each
    while overflow:
        batch = overflow[:max_per_file]
        overflow = overflow[max_per_file:]

        new_name = f"repositories-{next_num:03d}.yaml"
        new_path = os.path.join(data_dir, new_name)
        file_repos[new_path] = batch
        new_files[new_path] = batch
        print(f"  Created {new_name} with {len(batch)} repos")
        next_num += 1

# ── Write all modified files ─────────────────────────────────────────
def write_repos_file(fpath, repos, is_primary=False):
    """Write a repositories YAML file preserving structure."""
    if is_primary:
        # Preserve the original file's header by reading it
        # and replacing only the repositories list
        with open(fpath) as f:
            original = f.read()
        # Find where 'repositories:' starts and replace from there
        idx = original.find('\nrepositories:')
        if idx >= 0:
            header = original[:idx + 1]
        else:
            header = "---\n# Repository configurations loaded dynamically by Terraform\n# This file allows easier management of repository definitions outside of tfvars\n\n"
    else:
        fnum = file_number(fpath)
        header = HEADER_TEMPLATE.format(file_num=f"{fnum:03d}")

    with open(fpath, 'w') as f:
        if is_primary:
            f.write(header)
            f.write("repositories:\n")
        else:
            f.write(header.lstrip('\n'))
        for repo in repos:
            f.write(yaml.dump([repo], default_flow_style=False,
                              sort_keys=False, allow_unicode=True,
                              indent=2).replace('\n- ', '\n  - ', 1).rstrip('\n'))
            f.write('\n')

# Write back the primary file if it was split
primary = os.path.join(data_dir, 'repositories.yaml')
if primary in file_repos and len(file_repos[primary]) != total:
    write_repos_file(primary, file_repos[primary], is_primary=True)
    print(f"\n✏️  Updated {os.path.basename(primary)}")

# Write new overflow files
for fpath, repos in new_files.items():
    write_repos_file(fpath, repos, is_primary=False)
    print(f"✏️  Written {os.path.basename(fpath)}")

# ── Summary ──────────────────────────────────────────────────────────
print(f"\n✅ Split complete:")
for fpath in sorted(file_repos.keys()):
    print(f"  {os.path.basename(fpath)}: {len(file_repos[fpath])} repos")
print(f"  Total: {total} repos across {len(file_repos)} file(s)")
PYEOF
