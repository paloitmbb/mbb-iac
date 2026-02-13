# GitHub Repository Settings Module - Variables
# Accepts a map of existing repositories and the settings to apply

variable "repo_settings_requests" {
  description = "Map of existing repositories to apply settings to, keyed by repository name"
  type = map(object({
    # Metadata (not used by Terraform, used for filtering/auditing)
    organization = optional(string, "")

    # ── Branch Protection ──────────────────────────────────────
    enable_branch_protection        = optional(bool, false)
    protected_branch_pattern        = optional(string, "main")
    enforce_admins                  = optional(bool, false)
    require_signed_commits          = optional(bool, false)
    required_linear_history         = optional(bool, false)
    require_conversation_resolution = optional(bool, false)
    allows_deletions                = optional(bool, false)
    allows_force_pushes             = optional(bool, false)
    lock_branch                     = optional(bool, false)

    # Pull request reviews
    dismiss_stale_reviews           = optional(bool, true)
    require_code_owner_reviews      = optional(bool, false)
    required_approving_review_count = optional(number, 1)
    require_last_push_approval      = optional(bool, false)
    restrict_dismissals             = optional(bool, false)

    # Status checks
    required_status_checks = optional(list(string), [])
    strict_status_checks   = optional(bool, true)

    # ── Repository Ruleset ─────────────────────────────────────
    enable_ruleset      = optional(bool, false)
    ruleset_name        = optional(string, "default-ruleset")
    ruleset_target      = optional(string, "branch")
    ruleset_enforcement = optional(string, "active")
    ruleset_ref_include = optional(list(string), ["~DEFAULT_BRANCH"])
    ruleset_ref_exclude = optional(list(string), [])

    # Ruleset commit rules
    ruleset_block_creation         = optional(bool, false)
    ruleset_block_deletion         = optional(bool, true)
    ruleset_block_non_fast_forward = optional(bool, true)
    ruleset_require_linear_history = optional(bool, false)
    ruleset_require_signatures     = optional(bool, false)

    # Ruleset pull request rules
    ruleset_require_pull_request       = optional(bool, true)
    ruleset_dismiss_stale_reviews      = optional(bool, true)
    ruleset_require_code_owner_review  = optional(bool, false)
    ruleset_required_approvals         = optional(number, 1)
    ruleset_require_last_push_approval = optional(bool, false)
    ruleset_require_thread_resolution  = optional(bool, false)

    # Ruleset status checks
    ruleset_status_checks = optional(list(object({
      context        = string
      integration_id = optional(number)
    })), [])
    ruleset_strict_status_checks = optional(bool, true)

    # Ruleset bypass actors
    ruleset_bypass_actors = optional(list(object({
      actor_id    = number
      actor_type  = string
      bypass_mode = string
    })), [])
  }))
  default = {}
}
