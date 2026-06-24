# =============================================================================
# Certificate Renewal module — Main Configuration
# =============================================================================

terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    acme = {
      source  = "vancluever/acme"
      version = "~> 2.23.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-ctmp3-tfstate"
    storage_account_name = "stctmp3tfstate"
    container_name       = "tfstate"
    key                  = "ctmp3.cert.tfstate"
    use_oidc             = true
  }
}

# Retrieve subscription information from the current client context
data "azurerm_client_config" "current" {}

# Read remote state from the main infrastructure project to retrieve Key Vault
# and DNS Zone names dynamically without hardcoding.
data "terraform_remote_state" "main" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-ctmp3-tfstate"
    storage_account_name = "stctmp3tfstate"
    container_name       = "tfstate"
    key                  = var.remote_state_key
    use_oidc             = true
  }
}

# -----------------------------------------------------------------------------
# ACME Account Registration
# -----------------------------------------------------------------------------

# Generate a private key for Let's Encrypt registration
resource "tls_private_key" "acme_registration_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Register an account with Let's Encrypt
resource "acme_registration" "reg" {
  account_key_pem = tls_private_key.acme_registration_key.private_key_pem
  email_address   = var.acme_email
}

# -----------------------------------------------------------------------------
# Request SSL Certificate
# -----------------------------------------------------------------------------

# Generate a private key for the SSL certificate itself
resource "tls_private_key" "cert_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Request a wildcard certificate covering both base domain and subdomains
resource "acme_certificate" "certificate" {
  account_key_pem           = acme_registration.reg.account_key_pem
  common_name               = data.terraform_remote_state.main.outputs.domain_name
  subject_alternative_names = ["*.${data.terraform_remote_state.main.outputs.domain_name}"]

  # Let's Encrypt requires a password to generate P12 archives
  certificate_p12_password  = "SecretP12Password123!"

  dns_challenge {
    provider = "azuredns"
    config = {
      AZURE_SUBSCRIPTION_ID = data.azurerm_client_config.current.subscription_id
      AZURE_RESOURCE_GROUP  = data.terraform_remote_state.main.outputs.resource_group_name
      AZURE_ZONE_NAME       = data.terraform_remote_state.main.outputs.domain_name
      AZURE_AUTH_METHOD     = "cli" # Explicitly use Azure CLI credentials from azure/login
    }
  }
}

# -----------------------------------------------------------------------------
# Push Certificate to Azure Key Vault
# -----------------------------------------------------------------------------

# Upload the certificate PKCS12 file into Key Vault.
# Since Key Vault is not generating/renewing this certificate, no certificate_policy is required.
resource "azurerm_key_vault_certificate" "cert" {
  name         = var.certificate_name
  key_vault_id = data.terraform_remote_state.main.outputs.key_vault_id

  certificate {
    contents = acme_certificate.certificate.certificate_p12
    password = acme_certificate.certificate.certificate_p12_password
  }
}
