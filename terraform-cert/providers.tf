

provider "azurerm" {
  features {}
  use_oidc = true
}

provider "acme" {
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}
