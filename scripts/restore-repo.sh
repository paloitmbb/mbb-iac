#!/usr/bin/env bash
# restore-repo.sh — Download a backup tarball from Azure Blob Storage and push
#                   it back to a GitHub repository.
#
# Usage: ./scripts/restore-repo.sh
#
# Required env vars:
#   GH_BACKUP_TOKEN       — GitHub token with repo (push) scope
#   GITHUB_ORG            — GitHub organisation name
#   BLOB_NAME             — Exact blob name to restore (e.g. backup-my-repo-20260101-020000.tar.gz)
#   TARGET_REPO           — GitHub repository name to restore into
#   AZURE_STORAGE_ACCOUNT — Azure Storage account name (authenticated via az login / OIDC)
#   AZURE_CONTAINER_NAME  — Blob container name
#
# GitHub Actions outputs (written to GITHUB_OUTPUT when present):
#   restore_status, target_repo, blob_name

set -euo pipefail

: "${GH_BACKUP_TOKEN:?GH_BACKUP_TOKEN is required}"
: "${GITHUB_ORG:?GITHUB_ORG is required}"
: "${BLOB_NAME:?BLOB_NAME is required}"
: "${TARGET_REPO:?TARGET_REPO is required}"
: "${AZURE_STORAGE_ACCOUNT:?AZURE_STORAGE_ACCOUNT is required}"
: "${AZURE_CONTAINER_NAME:?AZURE_CONTAINER_NAME is required}"

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

echo "=== Restoring ${BLOB_NAME} → ${GITHUB_ORG}/${TARGET_REPO} ==="

# --- Download tarball from Azure Blob Storage ---
echo "Downloading blob: ${BLOB_NAME}"
az storage blob download \
  --account-name "${AZURE_STORAGE_ACCOUNT}" \
  --container-name "${AZURE_CONTAINER_NAME}" \
  --name "${BLOB_NAME}" \
  --file "${WORK_DIR}/${BLOB_NAME}" \
  --auth-mode login \
  --only-show-errors

DOWNLOAD_SIZE=$(stat -f%z "${WORK_DIR}/${BLOB_NAME}" 2>/dev/null \
  || stat -c%s "${WORK_DIR}/${BLOB_NAME}" 2>/dev/null \
  || echo "unknown")
echo "Download complete. Size: ${DOWNLOAD_SIZE} bytes"

# --- Extract tarball ---
echo "Extracting tarball..."
tar -xzf "${WORK_DIR}/${BLOB_NAME}" -C "${WORK_DIR}"

# Locate the bare repo directory (*.git) produced by backup-repo.sh
BARE_REPO_DIR=$(find "${WORK_DIR}" -maxdepth 1 -type d -name "*.git" | head -1)

if [[ -z "$BARE_REPO_DIR" ]]; then
  echo "❌ No bare git repository directory found inside the tarball."
  echo "   Expected a directory matching *.git at the top level."
  exit 1
fi

echo "Found bare repo: ${BARE_REPO_DIR}"

# --- Verify target repository exists on GitHub ---
echo "Verifying target repository ${GITHUB_ORG}/${TARGET_REPO} exists..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer ${GH_BACKUP_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${GITHUB_ORG}/${TARGET_REPO}")

if [[ "$HTTP_STATUS" != "200" ]]; then
  echo "❌ Repository ${GITHUB_ORG}/${TARGET_REPO} not found (HTTP ${HTTP_STATUS})."
  echo "   Create the repository first (e.g. via Terraform / repository-create workflow)"
  echo "   before running a restore."
  exit 1
fi

echo "Target repository confirmed."

# --- Push backup refs to GitHub ---
# --all pushes all branches from the backup with force (non-fast-forward ok).
# Unlike --mirror, this does NOT delete branches/tags that exist in
# the target but are absent from the backup — existing content is preserved.
REMOTE_URL="https://x-access-token:${GH_BACKUP_TOKEN}@github.com/${GITHUB_ORG}/${TARGET_REPO}.git"

echo "Pushing branches to ${GITHUB_ORG}/${TARGET_REPO}..."
cd "${BARE_REPO_DIR}"

git remote set-url origin "${REMOTE_URL}"

git push --all --force
echo "Branches pushed successfully."

# Push tags separately — some repos have no tags, which is fine
TAG_COUNT=$(git tag | wc -l | tr -d ' ')
if [[ "$TAG_COUNT" -gt 0 ]]; then
  echo "Pushing ${TAG_COUNT} tag(s)..."
  git push --tags --force
  echo "Tags pushed successfully."
else
  echo "No tags to push — skipping."
fi

echo "=== Restore of ${TARGET_REPO} completed successfully ==="

# --- Write outputs for GitHub Actions ---
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "restore_status=success"
    echo "target_repo=${TARGET_REPO}"
    echo "blob_name=${BLOB_NAME}"
  } >> "${GITHUB_OUTPUT}"
fi
