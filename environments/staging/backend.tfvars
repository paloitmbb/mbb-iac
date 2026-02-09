# HTTP Backend with GitHub Releases
# State storage: GitHub Releases
# State locking: GitHub Issues

address        = "https://github.com/paloitmbb/mbb-iac/releases/download/state-staging/terraform.tfstate"
lock_address   = "https://api.github.com/repos/paloitmbb/mbb-iac/issues"
unlock_address = "https://api.github.com/repos/paloitmbb/mbb-iac/issues"
lock_method    = "POST"
unlock_method  = "DELETE"
username       = "terraform"
# password set via TF_HTTP_PASSWORD environment variable (uses GITHUB_TOKEN)
