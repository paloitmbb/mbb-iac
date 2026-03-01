variable "repository_name" {
  description = "Name of the repository"
  type        = string
}

variable "description" {
  description = "Description of the repository"
  type        = string
  default     = ""
}

variable "visibility" {
  description = "Visibility of the repository (public, private, or internal)"
  type        = string
  default     = "private"

  validation {
    condition     = contains(["public", "private", "internal"], var.visibility)
    error_message = "Visibility must be one of: public, private, internal."
  }
}

variable "has_issues" {
  description = "Enable issues for the repository"
  type        = bool
  default     = true
}

variable "has_projects" {
  description = "Enable projects for the repository"
  type        = bool
  default     = false
}

variable "has_wiki" {
  description = "Enable wiki for the repository"
  type        = bool
  default     = false
}

variable "has_downloads" {
  description = "Enable downloads for the repository"
  type        = bool
  default     = false
}

variable "auto_init" {
  description = "Initialize the repository with a README file"
  type        = bool
  default     = false
}

variable "gitignore_template" {
  description = "Gitignore template to use"
  type        = string
  default     = null
}

variable "license_template" {
  description = "License template to use"
  type        = string
  default     = null
}

variable "allow_merge_commit" {
  description = "Allow merge commits"
  type        = bool
  default     = true
}

variable "allow_squash_merge" {
  description = "Allow squash merging"
  type        = bool
  default     = true
}

variable "allow_rebase_merge" {
  description = "Allow rebase merging"
  type        = bool
  default     = true
}

variable "allow_auto_merge" {
  description = "Allow auto-merge on pull requests"
  type        = bool
  default     = false
}

variable "delete_branch_on_merge" {
  description = "Delete branch after merge"
  type        = bool
  default     = true
}

variable "archived" {
  description = "Archive the repository"
  type        = bool
  default     = false
}

variable "archive_on_destroy" {
  description = "Archive the repository instead of deleting on destroy"
  type        = bool
  default     = true
}

variable "topics" {
  description = "List of topics for the repository"
  type        = list(string)
  default     = []
}

variable "vulnerability_alerts" {
  description = "Enable vulnerability alerts"
  type        = bool
  default     = true
}

variable "default_branch" {
  description = "Default branch name"
  type        = string
  default     = "main"
}

variable "branch_protection_rules" {
  description = "Branch protection rules configuration"
  type = object({
    pattern                         = string
    required_approving_review_count = optional(number, 1)
    require_code_owner_reviews      = optional(bool, false)
    dismiss_stale_reviews           = optional(bool, true)
    require_signed_commits          = optional(bool, false)
    enforce_admins                  = optional(bool, false)
    required_status_checks = optional(object({
      strict   = optional(bool, false)
      contexts = optional(list(string), [])
    }))
  })
  default = null
}

variable "webhooks" {
  description = "Repository webhooks"
  type = list(object({
    url          = string
    content_type = string
    insecure_ssl = bool
    active       = bool
    events       = list(string)
    secret       = optional(string)
  }))
  default = []
}

variable "template" {
  description = "Template repository to use"
  type = object({
    owner      = string
    repository = string
  })
  default = null
}

variable "pages" {
  description = "GitHub Pages configuration"
  type = object({
    source = object({
      branch = string
      path   = string
    })
    cname = optional(string)
  })
  default = null
}

variable "enable_advanced_security" {
  description = "Enable GitHub Advanced Security"
  type        = bool
  default     = false
}

variable "enable_secret_scanning" {
  description = "Enable secret scanning"
  type        = bool
  default     = false
}

variable "enable_secret_scanning_push_protection" {
  description = "Enable secret scanning push protection"
  type        = bool
  default     = false
}

