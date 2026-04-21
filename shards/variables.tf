variable "shard_id" {
  description = "The shard identifier (e.g., '001', '002'). Repos with topic 'state-group-<shard_id>' belong to this shard."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{3}$", var.shard_id))
    error_message = "shard_id must be a zero-padded 3-digit number (e.g., '001', '042')."
  }
}

variable "organization_name" {
  description = "Name of the GitHub organization (used for provider configuration)"
  type        = string
}

variable "repositories" {
  description = "List of repositories to manage (pass via tfvars or leave empty to use YAML)"
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
    archived           = optional(bool, false)
    archive_on_destroy = optional(bool, false)
  }))
  default = []
}

variable "teams" {
  description = "List of teams (pass via tfvars or leave empty to use YAML). Only team-repo bindings for repos in this shard are applied."
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
