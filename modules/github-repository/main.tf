resource "github_repository" "this" {
  name        = var.repository_name
  description = var.description
  visibility  = var.visibility

  has_issues    = var.has_issues
  has_projects  = var.has_projects
  has_wiki      = var.has_wiki
  has_downloads = var.has_downloads

  auto_init              = var.auto_init
  gitignore_template     = var.gitignore_template
  license_template       = var.license_template
  allow_merge_commit     = var.allow_merge_commit
  allow_squash_merge     = var.allow_squash_merge
  allow_rebase_merge     = var.allow_rebase_merge
  allow_auto_merge       = var.allow_auto_merge
  delete_branch_on_merge = var.delete_branch_on_merge
  archived               = var.archived
  archive_on_destroy     = var.archive_on_destroy

  topics = var.topics

  vulnerability_alerts = var.vulnerability_alerts

  # Only include security_and_analysis if advanced_security is enabled
  # GitHub requires GHAS to be purchased to configure these settings
  dynamic "security_and_analysis" {
    for_each = var.enable_advanced_security ? [1] : []
    content {
      advanced_security {
        status = "enabled"
      }
      secret_scanning {
        status = var.enable_secret_scanning ? "enabled" : "disabled"
      }
      secret_scanning_push_protection {
        status = var.enable_secret_scanning_push_protection ? "enabled" : "disabled"
      }
    }
  }

  dynamic "template" {
    for_each = var.template != null ? [var.template] : []
    content {
      owner      = template.value.owner
      repository = template.value.repository
    }
  }

  dynamic "pages" {
    for_each = var.pages != null ? [var.pages] : []
    content {
      source {
        branch = pages.value.source.branch
        path   = pages.value.source.path
      }
      cname = pages.value.cname
    }
  }
}

resource "github_branch_default" "this" {
  count = var.default_branch != null ? 1 : 0

  repository = github_repository.this.name
  branch     = var.default_branch

  depends_on = [github_repository.this]
}

resource "github_branch_protection" "this" {
  for_each = var.branch_protection_rules != null ? { (var.branch_protection_rules.pattern) = var.branch_protection_rules } : {}

  repository_id = github_repository.this.node_id
  pattern       = each.value.pattern

  required_status_checks {
    strict   = try(each.value.required_status_checks.strict, false)
    contexts = try(each.value.required_status_checks.contexts, [])
  }

  required_pull_request_reviews {
    dismiss_stale_reviews           = try(each.value.dismiss_stale_reviews, true)
    require_code_owner_reviews      = try(each.value.require_code_owner_reviews, false)
    required_approving_review_count = try(each.value.required_approving_review_count, 1)
  }

  require_signed_commits = try(each.value.require_signed_commits, false)
  enforce_admins         = try(each.value.enforce_admins, false)

  depends_on = [github_repository.this]
}

resource "github_repository_webhook" "this" {
  for_each = var.webhooks != null ? { for idx, webhook in var.webhooks : idx => webhook } : {}

  repository = github_repository.this.name
  active     = each.value.active

  configuration {
    url          = each.value.url
    content_type = each.value.content_type
    insecure_ssl = each.value.insecure_ssl
    secret       = each.value.secret
  }

  events = each.value.events

  depends_on = [github_repository.this]
}
