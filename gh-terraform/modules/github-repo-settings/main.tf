# GitHub Repository Settings Module
# Applies branch protection rules and rulesets to EXISTING repositories
# Uses data source to validate that the repository exists before applying changes

#--------------------------------------------------------------
# Data Source: Validate repository exists
#--------------------------------------------------------------
data "github_repository" "target" {
  for_each = var.repo_settings_requests

  name = each.key
}

#--------------------------------------------------------------
# Branch Protection Rules
#--------------------------------------------------------------
resource "github_branch_protection" "this" {
  for_each = {
    for name, req in var.repo_settings_requests : name => req
    if req.enable_branch_protection
  }

  repository_id = data.github_repository.target[each.key].node_id
  pattern       = each.value.protected_branch_pattern

  enforce_admins                  = each.value.enforce_admins
  require_signed_commits          = each.value.require_signed_commits
  required_linear_history         = each.value.required_linear_history
  require_conversation_resolution = each.value.require_conversation_resolution
  allows_deletions                = each.value.allows_deletions
  allows_force_pushes             = each.value.allows_force_pushes
  lock_branch                     = each.value.lock_branch

  required_pull_request_reviews {
    dismiss_stale_reviews           = each.value.dismiss_stale_reviews
    require_code_owner_reviews      = each.value.require_code_owner_reviews
    required_approving_review_count = each.value.required_approving_review_count
    require_last_push_approval      = each.value.require_last_push_approval
    restrict_dismissals             = each.value.restrict_dismissals
  }

  dynamic "required_status_checks" {
    for_each = length(each.value.required_status_checks) > 0 ? [1] : []
    content {
      strict   = each.value.strict_status_checks
      contexts = each.value.required_status_checks
    }
  }

  depends_on = [data.github_repository.target]
}

#--------------------------------------------------------------
# Repository Ruleset
#--------------------------------------------------------------
resource "github_repository_ruleset" "this" {
  for_each = {
    for name, req in var.repo_settings_requests : name => req
    if req.enable_ruleset
  }

  name        = each.value.ruleset_name
  repository  = data.github_repository.target[each.key].name
  target      = each.value.ruleset_target
  enforcement = each.value.ruleset_enforcement

  dynamic "conditions" {
    for_each = length(each.value.ruleset_ref_include) > 0 || length(each.value.ruleset_ref_exclude) > 0 ? [1] : []
    content {
      ref_name {
        include = each.value.ruleset_ref_include
        exclude = each.value.ruleset_ref_exclude
      }
    }
  }

  rules {
    # Commit rules
    creation                = each.value.ruleset_block_creation
    deletion                = each.value.ruleset_block_deletion
    non_fast_forward        = each.value.ruleset_block_non_fast_forward
    required_linear_history = each.value.ruleset_require_linear_history
    required_signatures     = each.value.ruleset_require_signatures

    # Pull request rules
    dynamic "pull_request" {
      for_each = each.value.ruleset_require_pull_request ? [1] : []
      content {
        dismiss_stale_reviews_on_push     = each.value.ruleset_dismiss_stale_reviews
        require_code_owner_review         = each.value.ruleset_require_code_owner_review
        required_approving_review_count   = each.value.ruleset_required_approvals
        require_last_push_approval        = each.value.ruleset_require_last_push_approval
        required_review_thread_resolution = each.value.ruleset_require_thread_resolution
      }
    }

    # Status check rules
    dynamic "required_status_checks" {
      for_each = length(each.value.ruleset_status_checks) > 0 ? [1] : []
      content {
        dynamic "required_check" {
          for_each = each.value.ruleset_status_checks
          content {
            context        = required_check.value.context
            integration_id = required_check.value.integration_id
          }
        }
        strict_required_status_checks_policy = each.value.ruleset_strict_status_checks
      }
    }
  }

  dynamic "bypass_actors" {
    for_each = each.value.ruleset_bypass_actors
    content {
      actor_id    = bypass_actors.value.actor_id
      actor_type  = bypass_actors.value.actor_type
      bypass_mode = bypass_actors.value.bypass_mode
    }
  }

  depends_on = [data.github_repository.target]
}
