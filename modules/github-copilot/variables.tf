variable "organization_name" {
  description = "Name of the GitHub organization"
  type        = string
}

variable "copilot_enabled" {
  description = "Enable GitHub Copilot for the organization"
  type        = bool
  default     = false
}

variable "public_code_suggestions" {
  description = "Policy for public code suggestions (enabled, disabled, unconfigured)"
  type        = string
  default     = "disabled"

  validation {
    condition     = contains(["enabled", "disabled", "unconfigured"], var.public_code_suggestions)
    error_message = "Public code suggestions must be one of: enabled, disabled, unconfigured."
  }
}

variable "ide_chat_enabled" {
  description = "Enable IDE chat features"
  type        = bool
  default     = true
}

variable "cli_enabled" {
  description = "Enable GitHub Copilot CLI"
  type        = bool
  default     = true
}

variable "policy_mode" {
  description = "Copilot policy mode (enabled, disabled, unconfigured)"
  type        = string
  default     = "enabled"

  validation {
    condition     = contains(["enabled", "disabled", "unconfigured"], var.policy_mode)
    error_message = "Policy mode must be one of: enabled, disabled, unconfigured."
  }
}

variable "seat_assignments" {
  description = "Copilot seat assignments for teams and users"
  type = object({
    teams = list(string)
    users = list(string)
  })
  default = {
    teams = []
    users = []
  }
}

variable "content_exclusions" {
  description = "Paths to exclude from Copilot suggestions"
  type        = list(string)
  default     = []
}

variable "github_token" {
  description = "GitHub token for API operations (optional, uses provider token by default)"
  type        = string
  default     = ""
  sensitive   = true
}
