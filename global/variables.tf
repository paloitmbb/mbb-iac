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

variable "teams" {
  description = "List of teams to manage. If provided, takes precedence over data/teams.yaml."
  type = list(object({
    name        = string
    description = optional(string, "")
    privacy     = optional(string, "closed")
    maintainers = optional(list(string), [])
    members     = optional(list(string), [])
    repositories = optional(list(object({
      repository = string
      permission = string
    })), [])
    deleted = optional(bool, false)
  }))
  default = []
}

variable "ghas_config" {
  description = "GitHub Advanced Security configuration"
  type = object({
    default_enabled = bool
    organization_level = object({
      enable_secret_scanning             = bool
      enable_push_protection             = bool
      enable_dependabot_alerts           = bool
      enable_dependabot_security_updates = bool
      enable_dependency_graph            = bool
    })
  })
}
