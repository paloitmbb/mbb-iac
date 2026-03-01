variable "repository_name" {
  description = "Name of the repository to configure security for"
  type        = string
}

variable "enable_dependabot_security_updates" {
  description = "Enable Dependabot automated security updates"
  type        = bool
  default     = true
}
