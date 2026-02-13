#!/usr/bin/env python3
"""
Script to add a repository settings request to data/repo-settings-requests.yaml.
Called by the issue-repo-settings.yml GitHub Actions workflow.

This module applies branch protection and/or ruleset settings to an EXISTING
repository — it does NOT create new repos. The Terraform module validates
existence via a data source lookup.

Usage:
  python3 scripts/update_repo_settings_yaml.py \
    --name "maybank-digital-frontend" \
    --org "maybank-sandbox" \
    --settings-type "Enable Branch Protection, Enable Repository Ruleset" \
    --branch-pattern "main" \
    --approvers "2" \
    --bp-options "Enforce Admins, Dismiss Stale Reviews, Require Code Owner Reviews" \
    --ruleset-name "my-ruleset" \
    --ruleset-enforcement "active" \
    --ruleset-rules "Block Deletion, Block Non-Fast-Forward, Require Pull Request" \
    --ruleset-approvals "2" \
    --justification "Adding branch protection as per security policy"
"""

import argparse
import os
import re
import sys
import yaml


def parse_settings_type(settings_str: str) -> dict:
    """Parse the settings type checkboxes into flags."""
    flags = {
        "enable_branch_protection": False,
        "enable_ruleset": False,
    }
    if not settings_str:
        return flags

    if "Enable Branch Protection" in settings_str:
        flags["enable_branch_protection"] = True
    if "Enable Repository Ruleset" in settings_str:
        flags["enable_ruleset"] = True

    return flags


def parse_bp_options(options_str: str) -> dict:
    """Parse branch protection option checkboxes into a dict of booleans."""
    opts = {
        "enforce_admins": False,
        "dismiss_stale_reviews": True,
        "require_code_owner_reviews": False,
        "require_signed_commits": False,
        "required_linear_history": False,
        "require_conversation_resolution": False,
        "require_last_push_approval": False,
        "restrict_dismissals": False,
        "allows_force_pushes": False,
        "lock_branch": False,
    }
    if not options_str:
        return opts

    option_map = {
        "Enforce Admins": "enforce_admins",
        "Dismiss Stale Reviews": "dismiss_stale_reviews",
        "Require Code Owner Reviews": "require_code_owner_reviews",
        "Require Signed Commits": "require_signed_commits",
        "Require Linear History": "required_linear_history",
        "Require Conversation Resolution": "require_conversation_resolution",
        "Require Last Push Approval": "require_last_push_approval",
        "Restrict Review Dismissals": "restrict_dismissals",
        "Allow Force Pushes": "allows_force_pushes",
        "Lock Branch": "lock_branch",
    }

    for label, key in option_map.items():
        if label in options_str:
            opts[key] = True

    return opts


def parse_ruleset_rules(rules_str: str) -> dict:
    """Parse ruleset rule checkboxes into a dict of booleans."""
    rules = {
        "ruleset_block_creation": False,
        "ruleset_block_deletion": True,
        "ruleset_block_non_fast_forward": True,
        "ruleset_require_linear_history": False,
        "ruleset_require_signatures": False,
        "ruleset_require_pull_request": True,
        "ruleset_dismiss_stale_reviews": True,
        "ruleset_require_code_owner_review": False,
        "ruleset_require_last_push_approval": False,
        "ruleset_require_thread_resolution": False,
    }
    if not rules_str:
        return rules

    rule_map = {
        "Block Creation": "ruleset_block_creation",
        "Block Deletion": "ruleset_block_deletion",
        "Block Non-Fast-Forward": "ruleset_block_non_fast_forward",
        "Require Linear History": "ruleset_require_linear_history",
        "Require Signatures": "ruleset_require_signatures",
        "Require Pull Request": "ruleset_require_pull_request",
        "Dismiss Stale Reviews on Push": "ruleset_dismiss_stale_reviews",
        "Require Code Owner Review": "ruleset_require_code_owner_review",
        "Require Last Push Approval": "ruleset_require_last_push_approval",
        "Require Thread Resolution": "ruleset_require_thread_resolution",
    }

    for label, key in rule_map.items():
        if label in rules_str:
            rules[key] = True

    return rules


def main():
    parser = argparse.ArgumentParser(
        description="Add repository settings request to data/repo-settings-requests.yaml"
    )
    parser.add_argument("--name", required=True, help="Repository name (must already exist)")
    parser.add_argument("--org", required=True, help="GitHub organization")
    parser.add_argument("--settings-type", default="", help="Which settings to apply (checkboxes)")
    parser.add_argument("--branch-pattern", default="main", help="Branch pattern for protection")
    parser.add_argument("--approvers", default="1", help="Required approving review count for branch protection")
    parser.add_argument("--bp-options", default="", help="Branch protection options (checkboxes)")
    parser.add_argument("--ruleset-name", default="", help="Ruleset name")
    parser.add_argument("--ruleset-enforcement", default="active", help="Ruleset enforcement level")
    parser.add_argument("--ruleset-rules", default="", help="Ruleset rules (checkboxes)")
    parser.add_argument("--ruleset-approvals", default="1", help="Required approvals for ruleset PR rule")
    parser.add_argument("--justification", default="", help="Reason for changes")
    args = parser.parse_args()

    # Validate repo name
    if not re.match(r'^[a-zA-Z0-9._-]+$', args.name):
        print(f"ERROR: Repository name '{args.name}' is invalid.")
        sys.exit(1)

    # Path to repo-settings-requests.yaml
    yaml_path = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "data",
        "repo-settings-requests.yaml",
    )

    # Load existing data or create new
    if os.path.exists(yaml_path):
        with open(yaml_path, "r") as f:
            data = yaml.safe_load(f) or {}
    else:
        os.makedirs(os.path.dirname(yaml_path), exist_ok=True)
        data = {}

    if "repo_settings_requests" not in data:
        data["repo_settings_requests"] = {}

    # Parse inputs
    settings_type = parse_settings_type(args.settings_type)
    bp_options = parse_bp_options(args.bp_options)
    ruleset_rules = parse_ruleset_rules(args.ruleset_rules)
    approvers = int(args.approvers) if args.approvers and args.approvers.isdigit() else 1
    ruleset_approvals = int(args.ruleset_approvals) if args.ruleset_approvals and args.ruleset_approvals.isdigit() else 1

    if not settings_type["enable_branch_protection"] and not settings_type["enable_ruleset"]:
        print("ERROR: At least one setting type must be selected (Branch Protection or Ruleset).")
        sys.exit(1)

    # Build settings request config
    config = {
        "organization": args.org,
    }

    # ── Branch Protection ──────────────────────────────────────
    config["enable_branch_protection"] = settings_type["enable_branch_protection"]
    if settings_type["enable_branch_protection"]:
        config["protected_branch_pattern"] = args.branch_pattern
        config["required_approving_review_count"] = approvers
        config.update(bp_options)

    # ── Ruleset ────────────────────────────────────────────────
    config["enable_ruleset"] = settings_type["enable_ruleset"]
    if settings_type["enable_ruleset"]:
        config["ruleset_name"] = args.ruleset_name if args.ruleset_name else f"{args.name}-ruleset"
        config["ruleset_enforcement"] = args.ruleset_enforcement
        config["ruleset_required_approvals"] = ruleset_approvals
        config.update(ruleset_rules)

    # Store entry (overwrites previous request for the same repo)
    data["repo_settings_requests"][args.name] = config

    # Write back
    with open(yaml_path, "w") as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False, allow_unicode=True)

    print(f"✅ Settings request for '{args.name}' added to {yaml_path}")
    print(f"   Organization: {args.org}")
    print(f"   Branch Protection: {settings_type['enable_branch_protection']}")
    if settings_type["enable_branch_protection"]:
        print(f"     Pattern: {args.branch_pattern}")
        print(f"     Approvers: {approvers}")
    print(f"   Ruleset: {settings_type['enable_ruleset']}")
    if settings_type["enable_ruleset"]:
        print(f"     Name: {config['ruleset_name']}")
        print(f"     Enforcement: {args.ruleset_enforcement}")
        print(f"     Approvals: {ruleset_approvals}")
    print(f"   Justification: {args.justification}")


if __name__ == "__main__":
    main()
