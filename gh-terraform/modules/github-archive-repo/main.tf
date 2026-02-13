# GitHub Archive Repository Module
# Archives existing GitHub repositories using the GitHub API
# Uses data source to validate existence, then calls API to set archived=true

#--------------------------------------------------------------
# Data Source: Validate repository exists before archiving
#--------------------------------------------------------------
data "github_repository" "target" {
  for_each = var.archive_requests

  name = each.key
}

#--------------------------------------------------------------
# Archive the repository via GitHub API
# Uses terraform_data + local-exec to PATCH the repo
# This only archives — it does NOT create or manage the repo in state
#--------------------------------------------------------------
resource "terraform_data" "archive" {
  for_each = var.archive_requests

  # Only re-run if the repo name changes (idempotent — archiving twice is safe)
  triggers_replace = [each.key]

  provisioner "local-exec" {
    command = <<-EOT
      curl -s -X PATCH \
        -H "Authorization: Bearer ${var.github_token}" \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        -d '{"archived": true}' \
        "https://api.github.com/repos/${each.value.organization}/${each.key}" \
        -o /tmp/archive_${each.key}.json -w "\nHTTP_STATUS:%%{http_code}"

      HTTP_CODE=$(tail -1 /tmp/archive_${each.key}.json | grep -o 'HTTP_STATUS:[0-9]*' | cut -d: -f2)
      if [ "$HTTP_CODE" != "200" ]; then
        echo "Failed to archive ${each.value.organization}/${each.key} (HTTP $HTTP_CODE)"
        cat /tmp/archive_${each.key}.json
        exit 1
      fi
      echo "Successfully archived ${each.value.organization}/${each.key}"
    EOT
  }

  depends_on = [data.github_repository.target]
}
