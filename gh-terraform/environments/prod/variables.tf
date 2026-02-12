# Production Environment Variables

variable "github_token" {
  description = "GitHub Personal Access Token with repo and admin:org scopes"
  type        = string
  sensitive   = true
}

variable "organization" {
  description = "GitHub organization name where repositories will be created"
  type        = string
}
variable "enterprise_slug" {
  description = "The slug or ID of the GitHub Enterprise"
  type        = string
  default     = ""
}
variable "default_topics" {
  description = "Default topics to apply to all repositories"
  type        = list(string)
  default     = ["production", "live", "terraform-managed"]
}

variable "repositories" {
  description = "Map of repositories to create with their configurations"
  type = map(object({
    description     = optional(string, "")
    visibility      = optional(string, "private")
    has_issues      = optional(bool, true)
    has_projects    = optional(bool, true)
    has_wiki        = optional(bool, true)
    has_downloads   = optional(bool, false)
    has_discussions = optional(bool, true)
    topics          = optional(list(string), [])
    is_template     = optional(bool, false)
    # archived             = optional(bool, false)
    vulnerability_alerts = optional(bool, true)

    # Stricter merge settings for production
    allow_merge_commit     = optional(bool, false)
    allow_squash_merge     = optional(bool, true)
    allow_rebase_merge     = optional(bool, false)
    allow_auto_merge       = optional(bool, false)
    delete_branch_on_merge = optional(bool, true)

    # default_branch      = optional(string, null)  # Enforced to "main"
    pages_source_branch = optional(string, null)
    pages_source_path   = optional(string, "/")

    # Strictest branch protection for production
    enable_branch_protection        = optional(bool, true)
    protected_branch_pattern        = optional(string, "main")
    enforce_admins                  = optional(bool, true)
    require_signed_commits          = optional(bool, true)
    dismiss_stale_reviews           = optional(bool, true)
    require_code_owner_reviews      = optional(bool, true)
    required_approving_review_count = optional(number, 2)
    required_linear_history         = optional(bool, true)
    require_conversation_resolution = optional(bool, true)
    allows_deletions                = optional(bool, false)
    allows_force_pushes             = optional(bool, false)
    lock_branch                     = optional(bool, false)
    require_last_push_approval      = optional(bool, true)
    restrict_dismissals             = optional(bool, true)
    required_status_checks          = optional(list(string), [])
    strict_status_checks            = optional(bool, true)

    # allow_update_branch         = optional(bool, true)
    # web_commit_signoff_required = optional(bool, true)
    # squash_merge_commit_title   = optional(string, "COMMIT_OR_PR_TITLE")
    # squash_merge_commit_message = optional(string, "COMMIT_MESSAGES")
    # merge_commit_title          = optional(string, "MERGE_MESSAGE")
    # merge_commit_message        = optional(string, "PR_TITLE")

    # All security features enabled for production
    enable_security_and_analysis           = optional(bool, true)
    advanced_security_status               = optional(string, "enabled")
    secret_scanning_status                 = optional(string, "enabled")
    secret_scanning_push_protection_status = optional(string, "enabled")

    # template_owner                = optional(string, null)
    # template_repository           = optional(string, null)
    # template_include_all_branches = optional(bool, false)

    team_permissions = optional(map(string), {})

    # Rulesets enabled by default for production
    enable_ruleset                     = optional(bool, true)
    ruleset_name                       = optional(string, "production-ruleset")
    ruleset_target                     = optional(string, "branch")
    ruleset_enforcement                = optional(string, "active")
    ruleset_ref_include                = optional(list(string), ["~DEFAULT_BRANCH"])
    ruleset_ref_exclude                = optional(list(string), [])
    ruleset_block_creation             = optional(bool, false)
    ruleset_block_deletion             = optional(bool, true)
    ruleset_block_non_fast_forward     = optional(bool, true)
    ruleset_require_linear_history     = optional(bool, true)
    ruleset_require_signatures         = optional(bool, true)
    ruleset_require_pull_request       = optional(bool, true)
    ruleset_dismiss_stale_reviews      = optional(bool, true)
    ruleset_require_code_owner_review  = optional(bool, true)
    ruleset_required_approvals         = optional(number, 2)
    ruleset_require_last_push_approval = optional(bool, true)
    ruleset_require_thread_resolution  = optional(bool, true)
    ruleset_status_checks = optional(list(object({
      context        = string
      integration_id = optional(number)
    })), [])
    ruleset_strict_status_checks = optional(bool, true)
    ruleset_bypass_actors = optional(list(object({
      actor_id    = number
      actor_type  = string
      bypass_mode = string
    })), [])

    autolink_references = optional(map(object({
      key_prefix          = string
      target_url_template = string
      is_alphanumeric     = optional(bool, true)
    })), {})

    deploy_keys = optional(map(object({
      key       = string
      read_only = optional(bool, true)
    })), {})

    # enable_dependabot_security_updates = optional(bool, true)  # Enforced: always enabled
    # enable_dependabot_version_updates  = optional(bool, true)
    # dependabot_config_content          = optional(string, null)
    # dependabot_updates = optional(list(object({
    #   package-ecosystem = string
    #   directory         = string
    #   schedule = object({
    #     interval = string
    #     day      = optional(string)
    #     time     = optional(string)
    #     timezone = optional(string)
    #   })
    #   open-pull-requests-limit = optional(number, 5)
    #   reviewers                = optional(list(string), [])
    #   assignees                = optional(list(string), [])
    #   labels                   = optional(list(string), [])
    #   commit-message = optional(object({
    #     prefix = optional(string)
    #   }))
    #   ignore = optional(list(object({
    #     dependency-name = string
    #     versions        = optional(list(string), [])
    #   })), [])
    # })), [])
    # dependabot_commit_message      = optional(string, "Add Dependabot configuration")
    # dependabot_commit_author       = optional(string, "Terraform")
    # dependabot_commit_email        = optional(string, "terraform@example.com")
    # dependabot_overwrite_on_create = optional(bool, true)
  }))
  default = {}
}
