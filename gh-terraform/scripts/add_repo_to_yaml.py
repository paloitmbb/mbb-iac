#!/usr/bin/env python3
"""
Script to add a new repository definition to data/repositories.yaml.
Called by the issue-new-repo.yml GitHub Actions workflow.

Usage:
  python3 scripts/add_repo_to_yaml.py \
    --name "maybank-digital-frontend" \
    --org "maybank-sandbox" \
    --description "Frontend application" \
    --visibility "private" \
    --topics "frontend, react" \
    --environment "all" \
    --merge-strategy "squash-only" \
    --approvers "2" \
    --features "Enable Issues, Enable Projects, Enable Branch Protection"
"""

import argparse
import os
import re
import sys
import yaml


def parse_features(features_str: str) -> dict:
    """Parse the checkbox features string into a dict of booleans."""
    features = {
        "has_issues": False,
        "has_projects": False,
        "enable_branch_protection": False,
        "enable_ruleset": False,
    }
    if not features_str:
        return features

    feature_map = {
        "Enable Issues": "has_issues",
        "Enable Projects": "has_projects",
        "Enable Branch Protection": "enable_branch_protection",
        "Enable Repository Ruleset": "enable_ruleset",
    }

    for label, key in feature_map.items():
        if label in features_str:
            features[key] = True

    return features


def parse_merge_strategy(strategy: str) -> dict:
    """Parse merge strategy dropdown into individual booleans."""
    strategies = {
        "squash-only": {"allow_merge_commit": False, "allow_squash_merge": True, "allow_rebase_merge": False},
        "merge-only": {"allow_merge_commit": True, "allow_squash_merge": False, "allow_rebase_merge": False},
        "rebase-only": {"allow_merge_commit": False, "allow_squash_merge": False, "allow_rebase_merge": True},
        "all": {"allow_merge_commit": True, "allow_squash_merge": True, "allow_rebase_merge": True},
    }
    return strategies.get(strategy, strategies["squash-only"])


def parse_topics(topics_str: str) -> list:
    """Parse comma-separated topics into a list."""
    if not topics_str or topics_str.strip() == "":
        return []
    return [t.strip() for t in topics_str.split(",") if t.strip()]


def main():
    parser = argparse.ArgumentParser(description="Add a repository to data/repositories.yaml")
    parser.add_argument("--name", required=True, help="Repository name")
    parser.add_argument("--org", required=True, help="GitHub organization")
    parser.add_argument("--description", required=True, help="Repository description")
    parser.add_argument("--visibility", default="private", help="Repository visibility")
    parser.add_argument("--topics", default="", help="Comma-separated topics")
    parser.add_argument("--environment", default="all", help="Target environment")
    parser.add_argument("--merge-strategy", default="squash-only", help="Merge strategy")
    parser.add_argument("--approvers", default="2", help="Required approving review count")
    parser.add_argument("--features", default="", help="Enabled features")
    args = parser.parse_args()

    # Validate repo name: only alphanumeric, hyphens, underscores allowed
    if not re.match(r'^[a-zA-Z0-9._-]+$', args.name):
        print(f"ERROR: Repository name '{args.name}' is invalid. Only alphanumeric characters, hyphens, underscores, and dots are allowed.")
        sys.exit(1)

    # Path to repositories.yaml
    yaml_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data", "repositories.yaml")

    # Load existing data or create new
    if os.path.exists(yaml_path):
        with open(yaml_path, "r") as f:
            data = yaml.safe_load(f) or {}
    else:
        os.makedirs(os.path.dirname(yaml_path), exist_ok=True)
        data = {}

    if "repositories" not in data:
        data["repositories"] = {}

    # Check for duplicates
    if args.name in data["repositories"]:
        print(f"ERROR: Repository '{args.name}' already exists in {yaml_path}")
        sys.exit(1)

    # Parse inputs
    features = parse_features(args.features)
    merge_settings = parse_merge_strategy(args.merge_strategy)
    topics = parse_topics(args.topics)
    approvers = int(args.approvers) if args.approvers and args.approvers.isdigit() else 2

    # Build repository config
    # NOTE: organization is NOT stored in YAML — it comes from the issue template
    # and is passed directly as TF_VAR_organization in the workflow.
    # "organization": args.org,
    repo_config = {
        "description": args.description,
        "visibility": args.visibility,
    }

    if topics:
        repo_config["topics"] = topics

    # Features
    repo_config["has_issues"] = features["has_issues"]
    repo_config["has_projects"] = features["has_projects"]

    # Merge settings
    repo_config.update(merge_settings)

    # Branch protection
    repo_config["enable_branch_protection"] = features["enable_branch_protection"]
    if features["enable_branch_protection"]:
        repo_config["required_approving_review_count"] = approvers

    # Ruleset
    if features["enable_ruleset"]:
        repo_config["enable_ruleset"] = True
        repo_config["ruleset_name"] = f"{args.name}-protection"

    # Security (enforced by module, but include for visibility)
    repo_config["vulnerability_alerts"] = True
    repo_config["enable_security_and_analysis"] = True
    repo_config["advanced_security_status"] = "enabled"
    repo_config["secret_scanning_status"] = "enabled"
    repo_config["secret_scanning_push_protection_status"] = "enabled"

    # Environment targeting
    repo_config["environment"] = args.environment

    # Add to data
    data["repositories"][args.name] = repo_config

    # Write back
    with open(yaml_path, "w") as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False, allow_unicode=True)

    print(f"✅ Added repository '{args.name}' (org: {args.org}) to {yaml_path}")
    print(f"   Visibility: {args.visibility}")
    print(f"   Environment: {args.environment}")
    print(f"   Topics: {topics}")
    print(f"   Branch Protection: {features['enable_branch_protection']}")
    print(f"   Approvers: {approvers}")


if __name__ == "__main__":
    main()
