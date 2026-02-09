# HTTP Backend with GitHub Releases
# Replace 'your-org' with your actual GitHub organization name

address        = "https://github.com/paloitmbb/mbb-iac/releases/download/state-dev/terraform.tfstate"
lock_address   = "https://api.github.com/repos/paloitmbb/mbb-iac/git/refs/locks/dev"
unlock_address = "https://api.github.com/repos/paloitmbb/mbb-iac/git/refs/locks/dev"
username       = "terraform"
# password set via TF_HTTP_PASSWORD environment variable (uses GITHUB_TOKEN)
