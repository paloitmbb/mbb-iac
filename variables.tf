variable "organization_name" {
  description = "Name of the GitHub organization"
  type        = string
}

variable "organization" {
  description = "Organization configuration"
  type = object({
    name                            = string
    billing_email                   = string
    company                         = string
    description                     = string
    default_repository_permission   = string
    members_can_create_repositories = bool
  })
}

variable "repositories" {
  description = "List of repositories to manage"
  type = list(object({
    name        = string
    description = string
    visibility  = string
    features = object({
      has_issues   = bool
      has_projects = bool
      has_wiki     = bool
    })
    default_branch = string
    topics         = list(string)
    security = optional(object({
      enable_vulnerability_alerts            = bool
      enable_advanced_security               = bool
      enable_secret_scanning                 = bool
      enable_secret_scanning_push_protection = bool
      enable_dependabot_alerts               = bool
      enable_dependabot_security_updates     = bool
    }))
    branch_protection = optional(object({
      pattern                         = string
      required_approving_review_count = number
      require_code_owner_reviews      = bool
      dismiss_stale_reviews           = bool
      require_signed_commits          = bool
      enforce_admins                  = bool
    }))
    teams = optional(list(object({
      team       = string
      permission = string
    })))
  }))
  default = []
}

variable "ghas_config" {
  description = "GitHub Advanced Security configuration"
  type = object({
    default_enabled = bool
    organization_level = object({
      enable_secret_scanning   = bool
      enable_push_protection   = bool
      enable_dependabot_alerts = bool
      enable_dependency_graph  = bool
    })
  })
}

variable "teams" {
  description = "GitHub teams configuration"
  type = list(object({
    name        = string
    description = string
    privacy     = string
    members     = list(string)
    maintainers = list(string)
  }))
  default = []
}
