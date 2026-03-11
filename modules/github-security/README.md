# GitHub Security Module

This module manages GitHub Advanced Security (GHAS) settings for repositories.

## Features

- GitHub Advanced Security configuration
- Secret scanning
- Secret scanning push protection
- Dependabot alerts
- Dependabot security updates
- Vulnerability alerts

## Usage

```hcl
module "security" {
  source = "./modules/github-security"

  repository_name                        = "my-repo"
  enable_vulnerability_alerts            = true
  enable_advanced_security               = true
  enable_secret_scanning                 = true
  enable_secret_scanning_push_protection = true
  enable_dependabot_alerts               = true
  enable_dependabot_security_updates     = true
}
```

## Requirements

| Name      | Version  |
| --------- | -------- |
| terraform | >= 1.14.5 |
| github    | ~> 6.0   |

## Inputs

See `variables.tf` for a complete list of available inputs.

## Outputs

| Name                      | Description                          |
| ------------------------- | ------------------------------------ |
| repository_name           | The name of the repository           |
| advanced_security_enabled | Whether Advanced Security is enabled |
| secret_scanning_enabled   | Whether secret scanning is enabled   |
