#!/usr/bin/env bash
# backup-repo.sh — Clone a single repo, tar it, and upload to Azure Blob Storage
# Usage: ./scripts/backup-repo.sh <repo-name>
#
# Required env vars:
#   GH_BACKUP_TOKEN       — GitHub PAT with repo scope
#   GITHUB_ORG            — GitHub organisation name
#   AZURE_STORAGE_ACCOUNT — Azure Storage account name (OIDC auth via az login)
#   AZURE_CONTAINER_NAME  — Target blob container name
#
# Output env vars (via GITHUB_OUTPUT if available):
#   blob_name, blob_url, backup_size, backup_status

set -euo pipefail

REPO_NAME="${1:?Usage: backup-repo.sh <repo-name>}"

: "${GH_BACKUP_TOKEN:?Environment variable GH_BACKUP_TOKEN is required}"
: "${GITHUB_ORG:?Environment variable GITHUB_ORG is required}"
: "${AZURE_STORAGE_ACCOUNT:?Environment variable AZURE_STORAGE_ACCOUNT is required}"
: "${AZURE_CONTAINER_NAME:?Environment variable AZURE_CONTAINER_NAME is required}"

TIMESTAMP=$(date -u +"%Y%m%d-%H%M%S")
TARBALL_NAME="backup-${REPO_NAME}-${TIMESTAMP}.tar.gz"
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

echo "=== Backing up ${GITHUB_ORG}/${REPO_NAME} ==="

# --- Clone (mirror) ---
echo "Cloning ${REPO_NAME} (mirror)..."
git clone --mirror \
  "https://x-access-token:${GH_BACKUP_TOKEN}@github.com/${GITHUB_ORG}/${REPO_NAME}.git" \
  "${WORK_DIR}/${REPO_NAME}.git" 2>&1

# --- Create tarball ---
echo "Creating tarball: ${TARBALL_NAME}"
tar -czf "${WORK_DIR}/${TARBALL_NAME}" -C "${WORK_DIR}" "${REPO_NAME}.git"

BACKUP_SIZE=$(stat -f%z "${WORK_DIR}/${TARBALL_NAME}" 2>/dev/null \
  || stat -c%s "${WORK_DIR}/${TARBALL_NAME}" 2>/dev/null \
  || echo "unknown")
BACKUP_SIZE_MB="unknown"
if [[ "$BACKUP_SIZE" != "unknown" ]]; then
  BACKUP_SIZE_MB=$(awk "BEGIN {printf \"%.2f\", ${BACKUP_SIZE}/1048576}")
fi

echo "Tarball size: ${BACKUP_SIZE_MB} MB"

# --- Upload to Azure Blob Storage ---
BLOB_NAME="${AZURE_CONTAINER_NAME}/${TARBALL_NAME}"

echo "Uploading to Azure Blob Storage: ${BLOB_NAME}"
az storage blob upload \
  --account-name "${AZURE_STORAGE_ACCOUNT}" \
  --container-name "${AZURE_CONTAINER_NAME}" \
  --name "${TARBALL_NAME}" \
  --file "${WORK_DIR}/${TARBALL_NAME}" \
  --auth-mode login \
  --overwrite true \
  --only-show-errors

BLOB_URL=$(az storage blob url \
  --account-name "${AZURE_STORAGE_ACCOUNT}" \
  --container-name "${AZURE_CONTAINER_NAME}" \
  --name "${TARBALL_NAME}" \
  --auth-mode login \
  --output tsv 2>/dev/null || echo "N/A")

echo "Upload complete: ${BLOB_URL}"

# --- Write outputs for GitHub Actions ---
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "blob_name=${TARBALL_NAME}"
    echo "blob_url=${BLOB_URL}"
    echo "backup_size=${BACKUP_SIZE_MB} MB"
    echo "backup_status=success"
  } >> "${GITHUB_OUTPUT}"
fi

echo "=== Backup of ${REPO_NAME} completed successfully ==="
