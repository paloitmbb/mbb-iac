#!/usr/bin/env python3
"""
Manage GitHub Copilot licenses for an organization.
Supports assigning and revoking Copilot seat assignments via the GitHub REST API.

Usage:
    python manage_copilot_license.py --org <org> --action <assign|revoke> --users <user1,user2,...> --token <github_token>

Requires a GitHub PAT with 'manage_billing:copilot' scope.
"""

import argparse
import json
import sys
import urllib.request
import urllib.error


GITHUB_API_BASE = "https://api.github.com"


def make_request(url, token, method="GET", data=None):
    """Make an authenticated request to the GitHub API."""
    headers = {
        "Accept": "application/json",
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "X-GitHub-Api-Version": "2022-11-28",
    }

    if data is not None:
        data = json.dumps(data).encode("utf-8")

    req = urllib.request.Request(url, data=data, headers=headers, method=method)

    try:
        with urllib.request.urlopen(req) as response:
            body = response.read().decode("utf-8")
            if body:
                return response.status, json.loads(body)
            return response.status, {}
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8")
        try:
            error_body = json.loads(body)
        except json.JSONDecodeError:
            error_body = {"message": body}
        return e.code, error_body


def check_copilot_billing(org, token):
    """Check if the organization has Copilot billing enabled."""
    url = f"{GITHUB_API_BASE}/orgs/{org}/copilot/billing"
    status, response = make_request(url, token)

    if status == 200:
        seat_breakdown = response.get("seat_breakdown", {})
        print(f"Copilot billing status for '{org}':")
        print(f"  Plan: {response.get('seat_management_setting', 'N/A')}")
        print(f"  Total seats: {seat_breakdown.get('total', 'N/A')}")
        print(f"  Active seats: {seat_breakdown.get('active_this_cycle', 'N/A')}")
        print(f"  Inactive seats: {seat_breakdown.get('inactive_this_cycle', 'N/A')}")
        return True
    elif status == 404:
        print(f"ERROR: Copilot is not enabled for organization '{org}', "
              f"or the token lacks 'manage_billing:copilot' scope.")
        return False
    else:
        print(f"ERROR: Failed to check Copilot billing (HTTP {status}): "
              f"{response.get('message', 'Unknown error')}")
        return False


def get_current_seats(org, token):
    """Get the list of current Copilot seat assignments."""
    all_seats = []
    page = 1
    per_page = 100

    while True:
        url = f"{GITHUB_API_BASE}/orgs/{org}/copilot/billing/seats?page={page}&per_page={per_page}"
        status, response = make_request(url, token)

        if status != 200:
            print(f"ERROR: Failed to fetch Copilot seats (HTTP {status}): "
                  f"{response.get('message', 'Unknown error')}")
            return None

        seats = response.get("seats", [])
        all_seats.extend(seats)

        if len(seats) < per_page:
            break
        page += 1

    return all_seats


def assign_licenses(org, users, token):
    """Assign Copilot licenses to the specified users."""
    url = f"{GITHUB_API_BASE}/orgs/{org}/copilot/billing/selected_users"

    # Get current seats to check for already-assigned users
    current_seats = get_current_seats(org, token)
    current_users = set()
    if current_seats is not None:
        current_users = {
            seat.get("assignee", {}).get("login", "").lower()
            for seat in current_seats
        }

    already_assigned = []
    to_assign = []

    for user in users:
        if user.lower() in current_users:
            already_assigned.append(user)
        else:
            to_assign.append(user)

    if already_assigned:
        print(f"INFO: Users already have Copilot licenses: {', '.join(already_assigned)}")

    if not to_assign:
        print("INFO: All specified users already have Copilot licenses. Nothing to do.")
        return True

    print(f"Assigning Copilot licenses to: {', '.join(to_assign)}")

    data = {"selected_usernames": to_assign}
    status, response = make_request(url, token, method="POST", data=data)

    if status in (200, 201):
        assigned = response.get("seats_created", len(to_assign))
        print(f"SUCCESS: Assigned Copilot licenses to {assigned} user(s).")
        return True
    else:
        print(f"ERROR: Failed to assign licenses (HTTP {status}): "
              f"{response.get('message', 'Unknown error')}")
        if "errors" in response:
            for error in response["errors"]:
                print(f"  - {error}")
        return False


def revoke_licenses(org, users, token):
    """Revoke Copilot licenses from the specified users."""
    url = f"{GITHUB_API_BASE}/orgs/{org}/copilot/billing/selected_users"

    # Get current seats to check for users without licenses
    current_seats = get_current_seats(org, token)
    current_users = set()
    if current_seats is not None:
        current_users = {
            seat.get("assignee", {}).get("login", "").lower()
            for seat in current_seats
        }

    not_assigned = []
    to_revoke = []

    for user in users:
        if user.lower() not in current_users:
            not_assigned.append(user)
        else:
            to_revoke.append(user)

    if not_assigned:
        print(f"INFO: Users do not have Copilot licenses: {', '.join(not_assigned)}")

    if not to_revoke:
        print("INFO: None of the specified users have Copilot licenses. Nothing to do.")
        return True

    print(f"Revoking Copilot licenses from: {', '.join(to_revoke)}")

    data = {"selected_usernames": to_revoke}
    status, response = make_request(url, token, method="DELETE", data=data)

    if status in (200, 204):
        revoked = response.get("seats_cancelled", len(to_revoke)) if response else len(to_revoke)
        print(f"SUCCESS: Revoked Copilot licenses from {revoked} user(s).")
        return True
    else:
        print(f"ERROR: Failed to revoke licenses (HTTP {status}): "
              f"{response.get('message', 'Unknown error')}")
        if isinstance(response, dict) and "errors" in response:
            for error in response["errors"]:
                print(f"  - {error}")
        return False


def parse_users(users_string):
    """Parse a comma-separated or newline-separated list of usernames."""
    users = []
    for part in users_string.replace("\n", ",").split(","):
        user = part.strip().lstrip("@")
        if user:
            users.append(user)
    return users


def main():
    parser = argparse.ArgumentParser(
        description="Manage GitHub Copilot licenses for an organization"
    )
    parser.add_argument("--org", required=True, help="GitHub organization name")
    parser.add_argument(
        "--action",
        required=True,
        choices=["assign", "revoke"],
        help="Action to perform: assign or revoke",
    )
    parser.add_argument(
        "--users",
        required=True,
        help="Comma-separated list of GitHub usernames",
    )
    parser.add_argument(
        "--token",
        required=True,
        help="GitHub PAT with 'manage_billing:copilot' scope",
    )

    args = parser.parse_args()

    users = parse_users(args.users)
    if not users:
        print("ERROR: No valid usernames provided.")
        sys.exit(1)

    print(f"Organization: {args.org}")
    print(f"Action: {args.action}")
    print(f"Users: {', '.join(users)}")
    print("-" * 50)

    # Check Copilot billing is enabled
    if not check_copilot_billing(args.org, args.token):
        sys.exit(1)

    print("-" * 50)

    # Perform the requested action
    if args.action == "assign":
        success = assign_licenses(args.org, users, args.token)
    else:
        success = revoke_licenses(args.org, users, args.token)

    if not success:
        sys.exit(1)

    print("-" * 50)
    print("Done.")


if __name__ == "__main__":
    main()
