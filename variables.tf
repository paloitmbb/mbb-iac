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

variable "organization_secrets" {
  description = "Organization-level secrets"
  type = map(object({
    description = string
    visibility  = string
  }))
  default = {}
}

variable "organization_variables" {
  description = "Organization-level variables"
  type = map(object({
    value      = string
    visibility = string
  }))
  default = {}
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
    teams     = optional(list(object({
      team       = string
      permission = string
    })))
    secrets   = optional(map(object({
      description = string
    })))
    variables = optional(map(object({
      value = string
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

variable "copilot_config" {
  description = "GitHub Copilot configuration"
  type = object({
    enabled                 = bool
    public_code_suggestions = string
    ide_chat_enabled        = bool
    cli_enabled             = bool
    policy_mode             = string
    seat_assignments = object({
      teams = list(string)
      users = list(string)
    })
    content_exclusions = list(string)
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
