variable "team_name" {
  description = "Name of the GitHub team"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._-]+$", var.team_name))
    error_message = "Team name must contain only alphanumeric characters, hyphens, underscores, and periods."
  }
}

variable "description" {
  description = "Description of the team"
  type        = string
  default     = ""
}

variable "privacy" {
  description = "Privacy level of the team (secret or closed)"
  type        = string
  default     = "closed"

  validation {
    condition     = contains(["secret", "closed"], var.privacy)
    error_message = "Privacy must be either 'secret' or 'closed'."
  }
}

variable "repositories" {
  description = "List of repository names this team has access to"
  type        = list(string)
  default     = []
}

variable "permission" {
  description = "Permission level for team access to repositories"
  type        = string
  default     = "pull"

  validation {
    condition     = contains(["pull", "triage", "push", "maintain", "admin"], var.permission)
    error_message = "Permission must be one of: pull, triage, push, maintain, admin."
  }
}

variable "parent_team_id" {
  description = "ID of parent team for hierarchical structure"
  type        = number
  default     = null
}
