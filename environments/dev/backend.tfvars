# HTTP Backend with GitHub Releases
# State storage: GitHub Releases
# State locking: Disabled (GitHub Issues API doesn't work reliably)

address  = "https://github.com/paloitmbb/mbb-iac/releases/download/state-dev/terraform.tfstate"
username = "terraform"
# password set via TF_HTTP_PASSWORD environment variable (uses GITHUB_TOKEN)
# Note: Locking disabled - ensure only one person runs terraform at a time
