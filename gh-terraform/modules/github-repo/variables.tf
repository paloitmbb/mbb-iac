# GitHub Repository Module - Variables
# This module accepts a map of repositories and creates them using for_each

variable "repositories" {
  description = "Map of repositories to create with their configurations"
  type = map(object({
    # Basic Settings
    description          = optional(string, "")
    visibility           = optional(string, "private")
    has_issues           = optional(bool, true)
    has_projects         = optional(bool, true)
    has_wiki             = optional(bool, true)
    has_downloads        = optional(bool, false)
    has_discussions      = optional(bool, false)
    topics               = optional(list(string), [])
    is_template          = optional(bool, false)
    archived             = optional(bool, false)
    vulnerability_alerts = optional(bool, true)

    # Merge Settings
    allow_merge_commit     = optional(bool, true)
    allow_squash_merge     = optional(bool, true)
    allow_rebase_merge     = optional(bool, true)
    allow_auto_merge       = optional(bool, false)
    delete_branch_on_merge = optional(bool, true)

    # Branch Settings
    # default_branch      = optional(string, null)  # Enforced to "main"
    pages_source_branch = optional(string, null)
    pages_source_path   = optional(string, "/")

    # Branch Protection
    enable_branch_protection        = optional(bool, false)
    protected_branch_pattern        = optional(string, "main")
    enforce_admins                  = optional(bool, false)
    require_signed_commits          = optional(bool, false)
    dismiss_stale_reviews           = optional(bool, true)
    require_code_owner_reviews      = optional(bool, false)
    required_approving_review_count = optional(number, 1)
    required_linear_history         = optional(bool, false)
    require_conversation_resolution = optional(bool, false)
    allows_deletions                = optional(bool, false)
    allows_force_pushes             = optional(bool, false)
    lock_branch                     = optional(bool, false)
    require_last_push_approval      = optional(bool, false)
    restrict_dismissals             = optional(bool, false)
    required_status_checks          = optional(list(string), [])
    strict_status_checks            = optional(bool, true)

    # Enterprise Settings
    # allow_update_branch         = optional(bool, true)
    # web_commit_signoff_required = optional(bool, false)
    # squash_merge_commit_title   = optional(string, "COMMIT_OR_PR_TITLE")
    # squash_merge_commit_message = optional(string, "COMMIT_MESSAGES")
    # merge_commit_title          = optional(string, "MERGE_MESSAGE")
    # merge_commit_message        = optional(string, "PR_TITLE")

    # Security and Analysis (Enterprise/GHEC)
    enable_security_and_analysis           = optional(bool, true)
    advanced_security_status               = optional(string, "enabled")
    secret_scanning_status                 = optional(string, "enabled")
    secret_scanning_push_protection_status = optional(string, "enabled")

    # Template Repository
    # template_owner                = optional(string, null)
    # template_repository           = optional(string, null)
    # template_include_all_branches = optional(bool, false)

    # Team Access (Enterprise)
    team_permissions = optional(map(string), {})

    # Repository Ruleset (Enterprise)
    enable_ruleset                     = optional(bool, false)
    ruleset_name                       = optional(string, "default-ruleset")
    ruleset_target                     = optional(string, "branch")
    ruleset_enforcement                = optional(string, "active")
    ruleset_ref_include                = optional(list(string), ["~DEFAULT_BRANCH"])
    ruleset_ref_exclude                = optional(list(string), [])
    ruleset_block_creation             = optional(bool, false)
    ruleset_block_deletion             = optional(bool, true)
    ruleset_block_non_fast_forward     = optional(bool, true)
    ruleset_require_linear_history     = optional(bool, false)
    ruleset_require_signatures         = optional(bool, false)
    ruleset_require_pull_request       = optional(bool, true)
    ruleset_dismiss_stale_reviews      = optional(bool, true)
    ruleset_require_code_owner_review  = optional(bool, false)
    ruleset_required_approvals         = optional(number, 1)
    ruleset_require_last_push_approval = optional(bool, false)
    ruleset_require_thread_resolution  = optional(bool, false)
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

    # Autolink References (Enterprise)
    autolink_references = optional(map(object({
      key_prefix          = string
      target_url_template = string
      is_alphanumeric     = optional(bool, true)
    })), {})

    # Deploy Keys
    deploy_keys = optional(map(object({
      key       = string
      read_only = optional(bool, true)
    })), {})

    # Dependabot Configuration
    # enable_dependabot_security_updates = optional(bool, true)  # Enforced: always enabled
    # enable_dependabot_version_updates  = optional(bool, false)
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

variable "default_topics" {
  description = "Default topics to apply to all repositories if not specified"
  type        = list(string)
  default     = []
}
