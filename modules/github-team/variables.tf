variable "team_name" {
  description = "Name of the GitHub team (slug)"
  type        = string
}

variable "description" {
  description = "Description of the team"
  type        = string
  default     = ""
}

variable "privacy" {
  description = "Team privacy: closed or secret"
  type        = string
  default     = "closed"
  validation {
    condition     = contains(["closed", "secret"], var.privacy)
    error_message = "Privacy must be 'closed' or 'secret'"
  }
}

variable "maintainers" {
  description = "List of GitHub usernames to assign as maintainers"
  type        = list(string)
  default     = []
}

variable "members" {
  description = "List of GitHub usernames to assign as members"
  type        = list(string)
  default     = []
}

variable "repositories" {
  description = "List of repositories to grant the team access to"
  type = list(object({
    repository = string
    permission = string
  }))
  default = []
  validation {
    condition = alltrue([
      for repo in var.repositories : contains(["pull", "push", "repo-owner", "triage", "maintain", "admin"], repo.permission)
    ])
    error_message = "Permission must be one of: pull, push, repo-owner, triage, maintain, admin"
  }
}

variable "deleted" {
  description = "Mark the team for deletion (soft delete - removes resources but preserves state)"
  type        = bool
  default     = false
}
