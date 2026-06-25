

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

data "azurerm_client_config" "current" {}

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

resource "tls_private_key" "acme_registration_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "acme_registration" "reg" {
  account_key_pem = tls_private_key.acme_registration_key.private_key_pem
  email_address   = var.acme_email
}

resource "tls_private_key" "cert_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "acme_certificate" "certificate" {
  account_key_pem           = acme_registration.reg.account_key_pem
  common_name               = data.terraform_remote_state.main.outputs.domain_name
  subject_alternative_names = ["*.${data.terraform_remote_state.main.outputs.domain_name}"]

  
  certificate_p12_password  = "SecretP12Password123!"

  dns_challenge {
    provider = "azuredns"
    config = {
      AZURE_SUBSCRIPTION_ID = data.azurerm_client_config.current.subscription_id
      AZURE_RESOURCE_GROUP  = data.terraform_remote_state.main.outputs.resource_group_name
      AZURE_ZONE_NAME       = data.terraform_remote_state.main.outputs.domain_name
      AZURE_AUTH_METHOD     = "cli" 
    }
  }
}

resource "azurerm_key_vault_certificate" "cert" {
  name         = var.certificate_name
  key_vault_id = data.terraform_remote_state.main.outputs.key_vault_id

  certificate {
    contents = acme_certificate.certificate.certificate_p12
    password = acme_certificate.certificate.certificate_p12_password
  }
}
