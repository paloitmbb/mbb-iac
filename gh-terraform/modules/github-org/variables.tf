# GitHub Enterprise Organization Module - Variables
# This module accepts a map of organizations and creates them using for_each

variable "organizations" {
  description = "Map of organizations to create with their configurations"
  type = map(object({
    # Basic Settings
    display_name  = string
    description   = optional(string, "")
    billing_email = string
    admin_logins  = list(string)

    # Organization Profile
    company  = optional(string, "")
    blog     = optional(string, "")
    email    = optional(string, "")
    location = optional(string, "")

    # Whether to manage org settings (requires org admin access)
    manage_settings = optional(bool, false)

    # Repository Defaults
    has_organization_projects                = optional(bool, true)
    has_repository_projects                  = optional(bool, true)
    default_repository_permission            = optional(string, "read")
    members_can_create_repositories          = optional(bool, true)
    members_can_create_public_repositories   = optional(bool, false)
    members_can_create_private_repositories  = optional(bool, true)
    members_can_create_internal_repositories = optional(bool, true)
    members_can_fork_private_repositories    = optional(bool, false)

    # Security Defaults for New Repositories
    web_commit_signoff_required                                  = optional(bool, false)
    advanced_security_enabled_for_new_repositories               = optional(bool, true)
    secret_scanning_enabled_for_new_repositories                 = optional(bool, true)
    secret_scanning_push_protection_enabled_for_new_repositories = optional(bool, true)
    dependabot_alerts_enabled_for_new_repositories               = optional(bool, true)
    dependabot_security_updates_enabled_for_new_repositories     = optional(bool, true)
    dependency_graph_enabled_for_new_repositories                = optional(bool, true)

    # Teams
    teams = optional(map(object({
      description = optional(string, "")
      privacy     = optional(string, "closed")
      parent_id   = optional(number, null)
      members = optional(list(object({
        username = string
        role     = optional(string, "member")
      })), [])
    })), {})

    # Organization Members
    members = optional(list(object({
      username = string
      role     = optional(string, "member")
    })), [])
  }))
  default = {}
}

variable "enterprise_slug" {
  description = "The slug or ID of the GitHub Enterprise (required for creating orgs)"
  type        = string
}
