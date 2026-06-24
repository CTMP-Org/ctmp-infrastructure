# =============================================================================
# Certificate Renewal module — Providers Configuration
# =============================================================================

provider "azurerm" {
  features {}
  use_oidc = true
}

# The ACME provider configuration pointing to Let's Encrypt production directory
provider "acme" {
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}
