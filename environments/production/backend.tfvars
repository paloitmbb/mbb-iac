# HTTP Backend with GitHub Releases
# Replace 'your-org' with your actual GitHub organization name

address        = "https://github.com/your-org/mbb-iac/releases/download/state-production/terraform.tfstate"
lock_address   = "https://api.github.com/repos/your-org/mbb-iac/git/refs/locks/production"
unlock_address = "https://api.github.com/repos/your-org/mbb-iac/git/refs/locks/production"
username       = "terraform"
# password set via TF_HTTP_PASSWORD environment variable (uses GITHUB_TOKEN)
