#!/usr/bin/env python3
"""
GHES → GHEC Repository Migration Script.

Orchestrates repository migration using GitHub Enterprise Importer (GEI) CLI.
Handles pre-migration validation, migration execution, post-migration setup,
and verification.

Usage:
    python3 scripts/ghes_migrate.py \
        --ghes-api-url "https://ghes.company.com/api/v3" \
        --source-org "legacy-org" \
        --source-repo "my-repo" \
        --target-org "my-ghec-org" \
        --target-repo "my-repo" \
        --target-visibility "private" \
        --ghes-token "ghp_xxx" \
        --ghec-token "ghp_yyy" \
        --admins "user1,user2" \
        [--preserve-history] \
        [--archive-source] \
        [--lock-source]

Requires:
    - gh CLI with gei extension installed
    - GHES PAT: repo, admin:org scopes
    - GHEC PAT: repo, admin:org, workflow scopes
"""

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.request
import urllib.error


API_BASE_GHEC = "https://api.github.com"


# ──────────────────────────────────────────────
# HTTP helpers
# ──────────────────────────────────────────────

def api_request(url, token, method="GET", data=None):
    """Make an authenticated GitHub API request."""
    payload = json.dumps(data).encode() if data else None
    req = urllib.request.Request(url, data=payload, method=method)
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("X-GitHub-Api-Version", "2022-11-28")
    if data:
        req.add_header("Content-Type", "application/json")

    try:
        with urllib.request.urlopen(req) as resp:
            body = resp.read().decode()
            return {"ok": True, "status": resp.status, "data": json.loads(body) if body else {}}
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        try:
            err = json.loads(body)
        except json.JSONDecodeError:
            err = {"message": body}
        return {"ok": False, "status": e.code, "data": err}


def run_cmd(cmd, env=None):
    """Run a shell command and return (returncode, stdout, stderr)."""
    merged_env = {**os.environ, **(env or {})}
    result = subprocess.run(
        cmd, shell=True, capture_output=True, text=True, env=merged_env
    )
    return result.returncode, result.stdout.strip(), result.stderr.strip()


# ──────────────────────────────────────────────
# Validation
# ──────────────────────────────────────────────

def validate_ghes_repo(ghes_api_url, org, repo, token):
    """Validate that the source repository exists on GHES and is accessible."""
    url = f"{ghes_api_url}/repos/{org}/{repo}"
    result = api_request(url, token)

    if not result["ok"]:
        print(f"❌ Source repository '{org}/{repo}' not found on GHES (HTTP {result['status']})")
        return None

    data = result["data"]
    if data.get("archived"):
        print(f"❌ Source repository '{org}/{repo}' is already archived on GHES")
        return None

    print(f"✅ Source repository verified: {org}/{repo}")
    print(f"   Size:           {data.get('size', 0)} KB")
    print(f"   Default branch: {data.get('default_branch', 'N/A')}")
    print(f"   Visibility:     {data.get('visibility', 'N/A')}")
    print(f"   Archived:       {data.get('archived', False)}")

    return data


def validate_target_available(target_org, target_repo, ghec_token):
    """Check that the target repo name is not already taken in GHEC."""
    url = f"{API_BASE_GHEC}/repos/{target_org}/{target_repo}"
    result = api_request(url, ghec_token)

    if result["ok"]:
        print(f"❌ Target repository '{target_org}/{target_repo}' already exists in GHEC")
        return False

    if result["status"] == 404:
        print(f"✅ Target name '{target_org}/{target_repo}' is available in GHEC")
        return True

    print(f"⚠️  Unexpected response checking target (HTTP {result['status']})")
    return False


def validate_ghec_org(target_org, ghec_token):
    """Validate that the target GHEC organization exists."""
    url = f"{API_BASE_GHEC}/orgs/{target_org}"
    result = api_request(url, ghec_token)

    if not result["ok"]:
        print(f"❌ Target organization '{target_org}' not found in GHEC (HTTP {result['status']})")
        return False

    print(f"✅ Target organization verified: {target_org}")
    return True


def validate_gei_installed():
    """Check that GEI CLI extension is installed."""
    rc, stdout, stderr = run_cmd("gh gei --version")
    if rc != 0:
        print("❌ GEI CLI not found. Install with: gh extension install github/gh-gei")
        return False
    print(f"✅ GEI CLI installed: {stdout}")
    return True


# ──────────────────────────────────────────────
# Pre-migration: record source state
# ──────────────────────────────────────────────

def get_repo_stats(api_base, org, repo, token):
    """Get repository statistics for verification."""
    stats = {}

    # Branch count
    result = api_request(f"{api_base}/repos/{org}/{repo}/branches?per_page=100", token)
    stats["branches"] = len(result["data"]) if result["ok"] and isinstance(result["data"], list) else 0

    # Tag count
    result = api_request(f"{api_base}/repos/{org}/{repo}/tags?per_page=100", token)
    stats["tags"] = len(result["data"]) if result["ok"] and isinstance(result["data"], list) else 0

    # Open PR count
    result = api_request(f"{api_base}/repos/{org}/{repo}/pulls?state=open&per_page=1", token)
    stats["open_prs"] = len(result["data"]) if result["ok"] and isinstance(result["data"], list) else 0

    # Closed PR count
    result = api_request(f"{api_base}/repos/{org}/{repo}/pulls?state=closed&per_page=1", token)
    stats["closed_prs"] = len(result["data"]) if result["ok"] and isinstance(result["data"], list) else 0

    # Default branch HEAD SHA
    result = api_request(f"{api_base}/repos/{org}/{repo}", token)
    if result["ok"]:
        default_branch = result["data"].get("default_branch", "main")
        branch_result = api_request(
            f"{api_base}/repos/{org}/{repo}/branches/{default_branch}", token
        )
        if branch_result["ok"]:
            stats["head_sha"] = branch_result["data"].get("commit", {}).get("sha", "")
        stats["default_branch"] = default_branch

    return stats


def lock_source_repo(ghes_api_url, org, repo, token):
    """Set source repo to archived (read-only) to prevent changes during migration."""
    url = f"{ghes_api_url}/repos/{org}/{repo}"
    result = api_request(url, token, method="PATCH", data={"archived": True})
    if result["ok"]:
        print(f"🔒 Source repository locked (archived): {org}/{repo}")
        return True
    else:
        print(f"⚠️  Failed to lock source repo (HTTP {result['status']}): {result['data'].get('message', '')}")
        return False


def unlock_source_repo(ghes_api_url, org, repo, token):
    """Re-enable source repo (unarchive) if migration fails."""
    url = f"{ghes_api_url}/repos/{org}/{repo}"
    result = api_request(url, token, method="PATCH", data={"archived": False})
    if result["ok"]:
        print(f"🔓 Source repository unlocked: {org}/{repo}")
    else:
        print(f"⚠️  Failed to unlock source repo: {result['data'].get('message', '')}")


# ──────────────────────────────────────────────
# Migration execution
# ──────────────────────────────────────────────

def run_migration(ghes_api_url, source_org, source_repo, target_org, target_repo,
                  target_visibility, ghes_token, ghec_token):
    """Execute the GEI migration command."""
    cmd = (
        f"gh gei migrate-repo "
        f"--github-source-org {source_org} "
        f"--source-repo {source_repo} "
        f"--github-target-org {target_org} "
        f"--target-repo {target_repo} "
        f"--ghes-api-url {ghes_api_url} "
        f"--target-repo-visibility {target_visibility} "
        f"--verbose"
    )

    env = {
        "GH_SOURCE_PAT": ghes_token,
        "GH_PAT": ghec_token,
    }

    print(f"\n🚀 Starting GEI migration...")
    print(f"   Source: {source_org}/{source_repo} (GHES)")
    print(f"   Target: {target_org}/{target_repo} (GHEC)")
    print(f"   Visibility: {target_visibility}")
    print(f"   Command: {cmd}\n")

    rc, stdout, stderr = run_cmd(cmd, env=env)

    print("─" * 60)
    if stdout:
        print(stdout)
    if stderr:
        print(stderr)
    print("─" * 60)

    if rc != 0:
        print(f"\n❌ GEI migration failed (exit code: {rc})")
        return False, None

    # Try to extract migration ID from output
    migration_id = None
    for line in (stdout + stderr).split("\n"):
        if "migration-id" in line.lower() or "RM_" in line:
            parts = line.split()
            for part in parts:
                if part.startswith("RM_"):
                    migration_id = part
                    break

    print(f"\n✅ GEI migration command completed successfully")
    if migration_id:
        print(f"   Migration ID: {migration_id}")

    return True, migration_id


# ──────────────────────────────────────────────
# Post-migration setup
# ──────────────────────────────────────────────

def add_admins(target_org, target_repo, admins, ghec_token):
    """Add admin collaborators to the migrated repository."""
    if not admins:
        return

    print(f"\n👥 Adding admin collaborators...")
    for admin in admins:
        admin = admin.strip().lstrip("@")
        if not admin:
            continue

        url = f"{API_BASE_GHEC}/repos/{target_org}/{target_repo}/collaborators/{admin}"
        result = api_request(url, ghec_token, method="PUT", data={"permission": "admin"})

        if result["ok"] or result["status"] in (201, 204):
            print(f"   ✅ {admin} — added as admin")
        else:
            print(f"   ❌ {admin} — failed: {result['data'].get('message', 'Unknown error')}")


def apply_team_mappings(target_org, target_repo, team_mappings, ghec_token):
    """Apply team access mappings to the migrated repository."""
    if not team_mappings or team_mappings.strip() == "":
        return

    print(f"\n👥 Applying team access mappings...")
    for line in team_mappings.strip().split("\n"):
        line = line.strip()
        if not line or line.startswith("#"):
            continue

        # Parse: ghes-team → ghec-team : permission
        try:
            if "→" in line:
                parts = line.split("→")
            elif "->" in line:
                parts = line.split("->")
            else:
                print(f"   ⚠️  Skipping invalid mapping: {line}")
                continue

            ghec_part = parts[1].strip()
            if ":" in ghec_part:
                ghec_team, permission = ghec_part.rsplit(":", 1)
                ghec_team = ghec_team.strip()
                permission = permission.strip()
            else:
                ghec_team = ghec_part
                permission = "push"

            url = f"{API_BASE_GHEC}/orgs/{target_org}/teams/{ghec_team}/repos/{target_org}/{target_repo}"
            result = api_request(url, ghec_token, method="PUT", data={"permission": permission})

            if result["ok"] or result["status"] == 204:
                print(f"   ✅ {ghec_team} — {permission}")
            else:
                print(f"   ❌ {ghec_team} — failed: {result['data'].get('message', '')}")
        except Exception as e:
            print(f"   ⚠️  Error parsing mapping '{line}': {e}")


def enable_branch_protection(target_org, target_repo, default_branch, ghec_token):
    """Enable basic branch protection on the default branch."""
    url = f"{API_BASE_GHEC}/repos/{target_org}/{target_repo}/branches/{default_branch}/protection"

    data = {
        "required_status_checks": None,
        "enforce_admins": True,
        "required_pull_request_reviews": {
            "required_approving_review_count": 1,
            "dismiss_stale_reviews": True,
        },
        "restrictions": None,
    }

    result = api_request(url, ghec_token, method="PUT", data=data)
    if result["ok"]:
        print(f"\n🛡️  Branch protection enabled on '{default_branch}'")
    else:
        print(f"\n⚠️  Branch protection setup returned HTTP {result['status']}: {result['data'].get('message', '')}")


# ──────────────────────────────────────────────
# Verification
# ──────────────────────────────────────────────

def verify_migration(ghes_api_url, source_org, source_repo, ghes_token,
                     target_org, target_repo, ghec_token, source_stats):
    """Compare source and target repository stats to verify migration integrity."""
    print(f"\n📋 Verifying migration integrity...")

    target_stats = get_repo_stats(API_BASE_GHEC, target_org, target_repo, ghec_token)

    checks = []

    # Branch count
    s_branches = source_stats.get("branches", 0)
    t_branches = target_stats.get("branches", 0)
    match = s_branches == t_branches
    checks.append(("Branches", s_branches, t_branches, match))

    # Tag count
    s_tags = source_stats.get("tags", 0)
    t_tags = target_stats.get("tags", 0)
    match = s_tags == t_tags
    checks.append(("Tags", s_tags, t_tags, match))

    # HEAD SHA
    s_sha = source_stats.get("head_sha", "")[:7]
    t_sha = target_stats.get("head_sha", "")[:7]
    match = s_sha == t_sha
    checks.append(("HEAD SHA", s_sha, t_sha, match))

    # Print verification table
    print(f"\n{'Check':<20} {'Source':<15} {'Target':<15} {'Status':<10}")
    print(f"{'─' * 60}")

    all_pass = True
    for check_name, source_val, target_val, passed in checks:
        status = "✅ PASS" if passed else "❌ FAIL"
        if not passed:
            all_pass = False
        print(f"{check_name:<20} {str(source_val):<15} {str(target_val):<15} {status}")

    print(f"{'─' * 60}")

    if all_pass:
        print(f"\n✅ All verification checks passed!")
    else:
        print(f"\n⚠️  Some verification checks failed — review above.")

    return all_pass, checks


# ──────────────────────────────────────────────
# Archive source
# ──────────────────────────────────────────────

def archive_source(ghes_api_url, org, repo, token):
    """Archive the source GHES repo after successful migration."""
    url = f"{ghes_api_url}/repos/{org}/{repo}"

    # Update description to note migration
    result = api_request(url, token, method="PATCH", data={
        "archived": True,
        "description": f"[MIGRATED TO GHEC] — see GHEC for active development"
    })

    if result["ok"]:
        print(f"\n📦 Source repository archived: {org}/{repo}")
        return True
    else:
        print(f"\n⚠️  Failed to archive source: {result['data'].get('message', '')}")
        return False


# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="GHES → GHEC Repository Migration")
    parser.add_argument("--ghes-api-url", required=True, help="GHES API base URL")
    parser.add_argument("--source-org", required=True, help="Source GHES organization")
    parser.add_argument("--source-repo", required=True, help="Source GHES repository name")
    parser.add_argument("--target-org", required=True, help="Target GHEC organization")
    parser.add_argument("--target-repo", required=True, help="Target GHEC repository name")
    parser.add_argument("--target-visibility", default="private", choices=["private", "internal", "public"])
    parser.add_argument("--ghes-token", required=True, help="GHES PAT")
    parser.add_argument("--ghec-token", required=True, help="GHEC PAT")
    parser.add_argument("--admins", default="", help="Comma-separated admin usernames")
    parser.add_argument("--team-mappings", default="", help="Team mapping rules")
    parser.add_argument("--preserve-history", action="store_true", default=True)
    parser.add_argument("--archive-source", action="store_true", default=False)
    parser.add_argument("--lock-source", action="store_true", default=False)
    args = parser.parse_args()

    ghes_api_url = args.ghes_api_url.rstrip("/")

    print(f"{'=' * 70}")
    print(f"  GHES → GHEC Repository Migration")
    print(f"{'=' * 70}")
    print(f"  Source: {args.source_org}/{args.source_repo} (GHES)")
    print(f"  Target: {args.target_org}/{args.target_repo} (GHEC)")
    print(f"  Visibility: {args.target_visibility}")
    print(f"  Preserve History: {args.preserve_history}")
    print(f"  Archive Source: {args.archive_source}")
    print(f"  Lock Source: {args.lock_source}")
    print(f"{'=' * 70}")

    # ── Step 1: Validate GEI ──
    print(f"\n{'─' * 40}")
    print(f"Step 1: Validate prerequisites")
    print(f"{'─' * 40}")

    if not validate_gei_installed():
        sys.exit(1)

    # ── Step 2: Validate source repo ──
    print(f"\n{'─' * 40}")
    print(f"Step 2: Validate source repository (GHES)")
    print(f"{'─' * 40}")

    source_data = validate_ghes_repo(ghes_api_url, args.source_org, args.source_repo, args.ghes_token)
    if not source_data:
        sys.exit(1)

    # ── Step 3: Validate target ──
    print(f"\n{'─' * 40}")
    print(f"Step 3: Validate target (GHEC)")
    print(f"{'─' * 40}")

    if not validate_ghec_org(args.target_org, args.ghec_token):
        sys.exit(1)

    if not validate_target_available(args.target_org, args.target_repo, args.ghec_token):
        sys.exit(1)

    # ── Step 4: Record source state ──
    print(f"\n{'─' * 40}")
    print(f"Step 4: Record source repository state")
    print(f"{'─' * 40}")

    source_stats = get_repo_stats(ghes_api_url, args.source_org, args.source_repo, args.ghes_token)
    print(f"  Branches:       {source_stats.get('branches', 'N/A')}")
    print(f"  Tags:           {source_stats.get('tags', 'N/A')}")
    print(f"  Open PRs:       {source_stats.get('open_prs', 'N/A')}")
    print(f"  Default branch: {source_stats.get('default_branch', 'N/A')}")
    print(f"  HEAD SHA:       {source_stats.get('head_sha', 'N/A')[:12]}")

    # ── Step 5: Lock source (optional) ──
    if args.lock_source:
        print(f"\n{'─' * 40}")
        print(f"Step 5: Lock source repository")
        print(f"{'─' * 40}")
        lock_source_repo(ghes_api_url, args.source_org, args.source_repo, args.ghes_token)

    # ── Step 6: Run migration ──
    print(f"\n{'─' * 40}")
    print(f"Step 6: Execute GEI migration")
    print(f"{'─' * 40}")

    success, migration_id = run_migration(
        ghes_api_url, args.source_org, args.source_repo,
        args.target_org, args.target_repo, args.target_visibility,
        args.ghes_token, args.ghec_token
    )

    if not success:
        # Rollback: unlock source if we locked it
        if args.lock_source:
            print("\n🔄 Rolling back: unlocking source repository...")
            unlock_source_repo(ghes_api_url, args.source_org, args.source_repo, args.ghes_token)
        sys.exit(1)

    # Brief wait for GHEC to finalize
    print("\n⏳ Waiting 10 seconds for GHEC to finalize...")
    time.sleep(10)

    # ── Step 7: Post-migration setup ──
    print(f"\n{'─' * 40}")
    print(f"Step 7: Post-migration setup")
    print(f"{'─' * 40}")

    # Add admins
    admins = [a.strip() for a in args.admins.split(",") if a.strip()]
    add_admins(args.target_org, args.target_repo, admins, args.ghec_token)

    # Apply team mappings
    apply_team_mappings(args.target_org, args.target_repo, args.team_mappings, args.ghec_token)

    # Enable branch protection on default branch
    default_branch = source_stats.get("default_branch", "main")
    enable_branch_protection(args.target_org, args.target_repo, default_branch, args.ghec_token)

    # ── Step 8: Verify migration ──
    print(f"\n{'─' * 40}")
    print(f"Step 8: Verify migration integrity")
    print(f"{'─' * 40}")

    all_pass, checks = verify_migration(
        ghes_api_url, args.source_org, args.source_repo, args.ghes_token,
        args.target_org, args.target_repo, args.ghec_token, source_stats
    )

    # ── Step 9: Archive source (optional) ──
    if args.archive_source:
        print(f"\n{'─' * 40}")
        print(f"Step 9: Archive source repository")
        print(f"{'─' * 40}")

        if all_pass:
            archive_source(ghes_api_url, args.source_org, args.source_repo, args.ghes_token)
        else:
            print("⚠️  Skipping archive — verification checks did not all pass")
            # Unlock source if we locked it
            if args.lock_source:
                unlock_source_repo(ghes_api_url, args.source_org, args.source_repo, args.ghes_token)
    elif args.lock_source and not args.archive_source:
        # If we locked but not archiving, unlock after successful migration
        if all_pass:
            print("\n🔓 Migration successful — source left locked as archive is not requested")
        else:
            unlock_source_repo(ghes_api_url, args.source_org, args.source_repo, args.ghes_token)

    # ── Summary ──
    print(f"\n{'=' * 70}")
    print(f"  Migration Summary")
    print(f"{'=' * 70}")
    print(f"  Source:       {args.source_org}/{args.source_repo} (GHES)")
    print(f"  Target:       {args.target_org}/{args.target_repo} (GHEC)")
    print(f"  Migration ID: {migration_id or 'N/A'}")
    print(f"  Verification: {'✅ All checks passed' if all_pass else '⚠️ Some checks failed'}")
    print(f"  Target URL:   https://github.com/{args.target_org}/{args.target_repo}")
    print(f"{'=' * 70}")

    if not all_pass:
        print("\n⚠️  Migration completed with warnings. Review verification results.")
        sys.exit(1)

    print("\n✅ Migration completed successfully!")


if __name__ == "__main__":
    main()
