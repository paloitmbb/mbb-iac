#!/usr/bin/env python3
"""
Script to add an archive request to data/archive-requests.yaml.
Called by the issue-archive-repo.yml GitHub Actions workflow.

The archive module uses a separate YAML file (archive-requests.yaml) so that
the archive operation is handled by its own Terraform module with data-source
validation, keeping it decoupled from the main repo module.

Usage:
  python3 scripts/archive_repo_in_yaml.py \
    --name "maybank-digital-frontend" \
    --org "maybank-sandbox" \
    --reason "Deprecated" \
    --justification "Replaced by v2 frontend" \
    --lock-repo "true" \
    --point-of-contact "@johndoe"
"""

import argparse
import os
import re
import sys
import yaml


def parse_lock_repo(lock_str: str) -> bool:
    """Parse the lock_repo checkbox output from issue parser."""
    if not lock_str:
        return False
    # stefanbuck/github-issue-parser outputs checkbox as comma-separated labels
    return "Lock the repository after archiving" in lock_str


def main():
    parser = argparse.ArgumentParser(description="Add archive request to data/archive-requests.yaml")
    parser.add_argument("--name", required=True, help="Repository name to archive")
    parser.add_argument("--org", required=True, help="GitHub organization")
    parser.add_argument("--reason", default="Deprecated", help="Reason for archiving")
    parser.add_argument("--justification", default="", help="Detailed justification")
    parser.add_argument("--lock-repo", default="", help="Lock repo checkbox output")
    parser.add_argument("--point-of-contact", default="", help="Point of contact")
    args = parser.parse_args()

    # Validate repo name
    if not re.match(r'^[a-zA-Z0-9._-]+$', args.name):
        print(f"ERROR: Repository name '{args.name}' is invalid.")
        sys.exit(1)

    # Path to archive-requests.yaml
    yaml_path = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "data",
        "archive-requests.yaml",
    )

    # Load existing data or create new
    if os.path.exists(yaml_path):
        with open(yaml_path, "r") as f:
            data = yaml.safe_load(f) or {}
    else:
        os.makedirs(os.path.dirname(yaml_path), exist_ok=True)
        data = {}

    if "archive_requests" not in data:
        data["archive_requests"] = {}

    # Check for duplicates
    if args.name in data["archive_requests"]:
        existing = data["archive_requests"][args.name]
        if existing.get("archived", False):
            print(f"WARNING: Repository '{args.name}' already has an archive request.")
            sys.exit(0)

    # Parse lock_repo checkbox
    lock_repo = parse_lock_repo(args.lock_repo)

    # Build archive request config — organization is stored so Terraform can
    # filter archive requests to only process repos in the current provider org
    archive_config = {
        "organization": args.org,
        "archived": True,
        "reason": args.reason,
        "justification": args.justification,
        "lock_repo": lock_repo,
        "point_of_contact": args.point_of_contact,
    }

    data["archive_requests"][args.name] = archive_config

    # Write back
    with open(yaml_path, "w") as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False, allow_unicode=True)

    print(f"✅ Archive request for '{args.name}' added to {yaml_path}")
    print(f"   Organization: {args.org}")
    print(f"   Reason: {args.reason}")
    print(f"   Justification: {args.justification}")
    print(f"   Lock Repo: {lock_repo}")
    print(f"   Point of Contact: {args.point_of_contact}")


if __name__ == "__main__":
    main()
