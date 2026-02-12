# GitHub Repository Module
# Creates and configures GitHub repositories for Enterprise organizations
# Uses for_each internally to create multiple repositories from a map

#--------------------------------------------------------------
# GitHub Repositories
#--------------------------------------------------------------
resource "github_repository" "this" {
  for_each = var.repositories

  name        = each.key
  description = each.value.description
  visibility  = each.value.visibility

  # Features
  has_issues      = each.value.has_issues      #present
  has_projects    = each.value.has_projects    #present
  has_wiki        = each.value.has_wiki        #not present
  has_discussions = each.value.has_discussions #not present

  # Repository settings
  topics             = length(each.value.topics) > 0 ? each.value.topics : var.default_topics
  is_template        = each.value.is_template
  #archived           = each.value.archived
  archive_on_destroy = true # Enforced: always archive on destroy

  # Security
  vulnerability_alerts = each.value.vulnerability_alerts

  # Merge settings
  allow_merge_commit = each.value.allow_merge_commit
  allow_squash_merge = each.value.allow_squash_merge
  allow_rebase_merge = each.value.allow_rebase_merge
  # allow_auto_merge       = each.value.allow_auto_merge
  # delete_branch_on_merge = each.value.delete_branch_on_merge



  # Security and Analysis - only for private/internal repos, respect per-repo settings
  dynamic "security_and_analysis" {
    for_each = each.value.enable_security_and_analysis && each.value.visibility != "public" ? [1] : []
    content {
      dynamic "advanced_security" {
        for_each = each.value.advanced_security_status != "disabled" ? [1] : []
        content {
          status = each.value.advanced_security_status
        }
      }
      secret_scanning {
        status = each.value.secret_scanning_status
      }
      secret_scanning_push_protection {
        status = each.value.secret_scanning_push_protection_status
      }
    }
  }

  # # Pages (optional)
  # dynamic "pages" {
  #   for_each = each.value.pages_source_branch != null ? [1] : []
  #   content {
  #     source {
  #       branch = each.value.pages_source_branch
  #       path   = each.value.pages_source_path
  #     }
  #   }
  # }

  # # Template repository (create from template)
  # dynamic "template" {
  #   for_each = each.value.template_repository != null ? [1] : []
  #   content {
  #     owner                = each.value.template_owner
  #     repository           = each.value.template_repository
  #     include_all_branches = each.value.template_include_all_branches
  #   }
  # }

  lifecycle {
    prevent_destroy = false
  }
}

#--------------------------------------------------------------
# Default Branch Configuration
#--------------------------------------------------------------
resource "github_branch_default" "this" {
  for_each = var.repositories

  repository = github_repository.this[each.key].name
  branch     = "main" # Enforced: default branch is always main

  depends_on = [github_repository.this]
}

#--------------------------------------------------------------
# Branch Protection Rules
#--------------------------------------------------------------
resource "github_branch_protection" "main" {
  for_each = {
    for name, repo in var.repositories : name => repo
    if repo.enable_branch_protection
  }

  repository_id = github_repository.this[each.key].node_id
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

  depends_on = [github_repository.this]
}

#--------------------------------------------------------------
# Enterprise Features: Team Access
#--------------------------------------------------------------
locals {
  # Flatten team permissions for all repositories
  team_repo_permissions = flatten([
    for repo_name, repo in var.repositories : [
      for team_id, permission in repo.team_permissions : {
        repo_name  = repo_name
        team_id    = team_id
        permission = permission
      }
    ]
  ])
}

resource "github_team_repository" "teams" {
  for_each = {
    for item in local.team_repo_permissions :
    "${item.repo_name}-${item.team_id}" => item
  }

  team_id    = each.value.team_id
  repository = github_repository.this[each.value.repo_name].name
  permission = each.value.permission

  depends_on = [github_repository.this]
}

#--------------------------------------------------------------
# Enterprise Features: Repository Ruleset
#--------------------------------------------------------------
resource "github_repository_ruleset" "this" {
  for_each = {
    for name, repo in var.repositories : name => repo
    if repo.enable_ruleset
  }

  name        = each.value.ruleset_name
  repository  = github_repository.this[each.key].name
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

  depends_on = [github_repository.this]
}

#--------------------------------------------------------------
# Enterprise Features: Autolink References
#--------------------------------------------------------------
locals {
  # Flatten autolink references for all repositories
  autolink_refs = flatten([
    for repo_name, repo in var.repositories : [
      for ref_name, ref in repo.autolink_references : {
        repo_name           = repo_name
        ref_name            = ref_name
        key_prefix          = ref.key_prefix
        target_url_template = ref.target_url_template
        is_alphanumeric     = ref.is_alphanumeric
      }
    ]
  ])
}

resource "github_repository_autolink_reference" "this" {
  for_each = {
    for item in local.autolink_refs :
    "${item.repo_name}-${item.ref_name}" => item
  }

  repository          = github_repository.this[each.value.repo_name].name
  key_prefix          = each.value.key_prefix
  target_url_template = each.value.target_url_template
  is_alphanumeric     = each.value.is_alphanumeric

  depends_on = [github_repository.this]
}

#--------------------------------------------------------------
# Enterprise Features: Deploy Keys
#--------------------------------------------------------------
locals {
  # Flatten deploy keys for all repositories
  deploy_keys = flatten([
    for repo_name, repo in var.repositories : [
      for key_name, key in repo.deploy_keys : {
        repo_name = repo_name
        key_name  = key_name
        key       = key.key
        read_only = key.read_only
      }
    ]
  ])
}

resource "github_repository_deploy_key" "this" {
  for_each = {
    for item in local.deploy_keys :
    "${item.repo_name}-${item.key_name}" => item
  }

  title      = each.value.key_name
  repository = github_repository.this[each.value.repo_name].name
  key        = each.value.key
  read_only  = each.value.read_only

  depends_on = [github_repository.this]
}

#--------------------------------------------------------------
# Dependabot Configuration
#--------------------------------------------------------------
resource "github_repository_dependabot_security_updates" "this" {
  for_each = var.repositories # Enforced: always enabled

  repository = github_repository.this[each.key].name
  enabled    = true

  depends_on = [github_repository.this]
}

# resource "github_repository_file" "dependabot" {
#   for_each = {
#     for name, repo in var.repositories : name => repo
#     if repo.enable_dependabot_version_updates
#   }
#
#   repository = github_repository.this[each.key].name
#   branch     = "main"  # Enforced: default branch is always main
#   file       = ".github/dependabot.yml"
#   content = each.value.dependabot_config_content != null ? each.value.dependabot_config_content : yamlencode({
#     version = 2
#     updates = each.value.dependabot_updates
#   })
#   commit_message      = each.value.dependabot_commit_message
#   commit_author       = each.value.dependabot_commit_author
#   commit_email        = each.value.dependabot_commit_email
#   overwrite_on_create = each.value.dependabot_overwrite_on_create
#
#   depends_on = [github_repository.this]
# }
