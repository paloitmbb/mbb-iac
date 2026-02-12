# GitHub Archive Repository Module - Variables

variable "github_token" {
  description = "GitHub Personal Access Token for API calls"
  type        = string
  sensitive   = true
}

variable "archive_requests" {
  description = "Map of repositories to archive, keyed by repository name"
  type = map(object({
    # Archive settings
    organization     = optional(string, "")
    archived         = optional(bool, true)
    reason           = optional(string, "")
    justification    = optional(string, "")
    lock_repo        = optional(bool, false)
    point_of_contact = optional(string, "")
  }))
  default = {}
}
