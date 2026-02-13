#!/usr/bin/env python3
"""
Script to add a new enterprise organization definition to data/organizations.yaml.
Called by the issue-new-org.yml GitHub Actions workflow.

Usage:
  python3 scripts/add_org_to_yaml.py \
    --name "maybank-sandbox" \
    --display-name "Maybank Sandbox" \
    --description "Sandbox org for Maybank" \
    --billing-email "admin@maybank.com" \
    --admin-logins "user1,user2" \
    --default-repo-permission "read" \
    --members-can-create-repos "true" \
    --security-features "Advanced Security, Secret Scanning, Dependabot Alerts"
"""

import argparse
import os
import re
import sys
import yaml


def parse_security_features(features_str: str) -> dict:
    """Parse the checkbox security features string into a dict of booleans."""
    features = {
        "advanced_security_enabled_for_new_repositories": False,
        "secret_scanning_enabled_for_new_repositories": False,
        "secret_scanning_push_protection_enabled_for_new_repositories": False,
        "dependabot_alerts_enabled_for_new_repositories": False,
        "dependabot_security_updates_enabled_for_new_repositories": False,
        "dependency_graph_enabled_for_new_repositories": False,
    }
    if not features_str:
        return features

    feature_map = {
        "Advanced Security": "advanced_security_enabled_for_new_repositories",
        "Secret Scanning": "secret_scanning_enabled_for_new_repositories",
        "Secret Scanning Push Protection": "secret_scanning_push_protection_enabled_for_new_repositories",
        "Dependabot Alerts": "dependabot_alerts_enabled_for_new_repositories",
        "Dependabot Security Updates": "dependabot_security_updates_enabled_for_new_repositories",
        "Dependency Graph": "dependency_graph_enabled_for_new_repositories",
    }

    for label, key in feature_map.items():
        if label in features_str:
            features[key] = True

    return features


def parse_csv(csv_str: str) -> list:
    """Parse comma-separated string into a list."""
    if not csv_str or csv_str.strip() == "":
        return []
    return [item.strip() for item in csv_str.split(",") if item.strip()]


def main():
    parser = argparse.ArgumentParser(description="Add an organization to data/organizations.yaml")
    parser.add_argument("--name", required=True, help="Organization login name (slug)")
    parser.add_argument("--display-name", required=True, help="Organization display name")
    parser.add_argument("--description", default="", help="Organization description")
    parser.add_argument("--billing-email", required=True, help="Billing email address")
    parser.add_argument("--admin-logins", required=True, help="Comma-separated list of admin usernames")
    parser.add_argument("--company", default="", help="Company name")
    parser.add_argument("--blog", default="", help="Blog URL")
    parser.add_argument("--email", default="", help="Public email")
    parser.add_argument("--location", default="", help="Location")
    parser.add_argument("--default-repo-permission", default="read", help="Default repository permission")
    parser.add_argument("--members-can-create-repos", default="true", help="Members can create repos")
    parser.add_argument("--environment", default="all", help="Target environment")
    parser.add_argument("--security-features", default="", help="Enabled security features")
    args = parser.parse_args()

    # Validate org name: only alphanumeric, hyphens allowed
    if not re.match(r'^[a-zA-Z0-9-]+$', args.name):
        print(f"ERROR: Organization name '{args.name}' is invalid. Only alphanumeric characters and hyphens are allowed.")
        sys.exit(1)

    # Path to organizations.yaml
    yaml_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data", "organizations.yaml")

    # Load existing data or create new
    if os.path.exists(yaml_path):
        with open(yaml_path, "r") as f:
            data = yaml.safe_load(f) or {}
    else:
        os.makedirs(os.path.dirname(yaml_path), exist_ok=True)
        data = {}

    if "organizations" not in data:
        data["organizations"] = {}

    # Check for duplicates
    if args.name in data["organizations"]:
        print(f"ERROR: Organization '{args.name}' already exists in {yaml_path}")
        sys.exit(1)

    # Parse inputs
    security_features = parse_security_features(args.security_features)
    admin_logins = parse_csv(args.admin_logins)
    members_can_create = args.members_can_create_repos.lower() in ("true", "yes", "1")

    if not admin_logins:
        print("ERROR: At least one admin login is required.")
        sys.exit(1)

    # Build organization config
    org_config = {
        "display_name": args.display_name,
        "description": args.description,
        "billing_email": args.billing_email,
        "admin_logins": admin_logins,
    }

    # Profile fields (only add non-empty)
    if args.company:
        org_config["company"] = args.company
    if args.blog:
        org_config["blog"] = args.blog
    if args.email:
        org_config["email"] = args.email
    if args.location:
        org_config["location"] = args.location

    # Repository defaults
    org_config["default_repository_permission"] = args.default_repo_permission
    org_config["members_can_create_repositories"] = members_can_create
    org_config["members_can_create_public_repositories"] = False
    org_config["members_can_create_private_repositories"] = members_can_create
    org_config["members_can_create_internal_repositories"] = members_can_create
    org_config["members_can_fork_private_repositories"] = False

    # Security features
    org_config.update(security_features)

    # Environment targeting
    org_config["environment"] = args.environment

    # Add to data
    data["organizations"][args.name] = org_config

    # Write back
    with open(yaml_path, "w") as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False, allow_unicode=True)

    print(f"✅ Added organization '{args.name}' to {yaml_path}")
    print(f"   Display Name: {args.display_name}")
    print(f"   Billing Email: {args.billing_email}")
    print(f"   Admin Logins: {admin_logins}")
    print(f"   Default Repo Permission: {args.default_repo_permission}")
    print(f"   Members Can Create Repos: {members_can_create}")


if __name__ == "__main__":
    main()
