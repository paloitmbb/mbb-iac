variable "repository_name" {
  description = "Name of the repository to configure security for"
  type        = string
}

variable "enable_vulnerability_alerts" {
  description = "Enable vulnerability alerts for the repository"
  type        = bool
  default     = true
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
  description = "Enable push protection for secret scanning"
  type        = bool
  default     = false
}

variable "enable_dependabot_alerts" {
  description = "Enable Dependabot alerts"
  type        = bool
  default     = true
}

variable "enable_dependabot_security_updates" {
  description = "Enable Dependabot security updates"
  type        = bool
  default     = true
}
