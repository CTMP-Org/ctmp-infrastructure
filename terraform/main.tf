# =============================================================================
# Cross-Cloud GitOps Training Portal — Root Terraform Configuration
# =============================================================================
# Orchestrates all child modules to deploy the complete infrastructure in
# Azure Central India. Every resource is locked to centralindia.
#
# Architecture:
#   - Networking: VNet with 5 subnets, 4 NSGs (zero-trust), Public/Private DNS
#   - App Gateway: WAF_v2 — the ONLY public IP in the infrastructure
#   - AKS: Private cluster with AGIC, system + user node pools (Standard_D2s_v5)
#   - Key Vault: RBAC-enabled, private endpoint only
#   - Function App: Premium EP1, VNet-integrated, User-Assigned Managed Identity
#   - AI Foundry: Hub + Project + GPT-4o, all private
#
# Remote State Backend:
#   Stored in Azure Storage Account. Create the storage account manually first:
#     az group create -n rg-ctmp3-tfstate -l centralindia
#     az storage account create -n stctmp3tfstate -g rg-ctmp3-tfstate -l centralindia --sku Standard_LRS
#     az storage container create -n tfstate --account-name stctmp3tfstate
# =============================================================================

terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-ctmp3-tfstate"
    storage_account_name = "stctmp3tfstate"
    container_name       = "tfstate"
    key                  = "ctmp3.terraform.tfstate"
    use_oidc             = true # GitHub Actions OIDC — no client secrets
  }
}

# -----------------------------------------------------------------------------
# Provider Configuration — locked to Central India
# -----------------------------------------------------------------------------

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
  use_oidc = true # OIDC for CI/CD pipelines
}

provider "azapi" {}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "azurerm_client_config" "current" {}

# -----------------------------------------------------------------------------
# Resource Group
# -----------------------------------------------------------------------------

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

# -----------------------------------------------------------------------------
# Locals
# -----------------------------------------------------------------------------

locals {
  common_tags = merge(var.tags, {
    project     = "ctmp3"
    environment = var.environment
    managed_by  = "terraform"
    region      = var.location
  })
}

# =============================================================================
# Module: Networking
# =============================================================================
# Creates VNet, subnets, NSGs (zero-trust), Public DNS, Private DNS zones
# =============================================================================

module "networking" {
  source = "./modules/networking"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  prefix              = var.prefix
  tags                = local.common_tags

  vnet_address_space   = var.vnet_address_space
  appgw_subnet_cidr    = var.appgw_subnet_cidr
  aks_subnet_cidr      = var.aks_subnet_cidr
  func_subnet_cidr     = var.func_subnet_cidr
  pe_subnet_cidr       = var.pe_subnet_cidr
  aks_api_subnet_cidr  = var.aks_api_subnet_cidr
  jumpbox_subnet_cidr  = var.jumpbox_subnet_cidr
  public_dns_zone_name = var.domain_name
  jumpbox_ssh_allowed_source_address_prefix = var.jumpbox_ssh_allowed_source_address_prefix
}

# =============================================================================
# Module: Application Gateway (deploy BEFORE AKS so AGIC can reference it)
# =============================================================================
# The ONLY resource with a public IP. WAF_v2 with OWASP 3.2 in Prevention mode.
# =============================================================================

module "app_gateway" {
  source = "./modules/app_gateway"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  prefix              = var.prefix
  tags                = local.common_tags

  appgw_subnet_id       = module.networking.appgw_subnet_id
  waf_mode              = "Prevention"
  owasp_ruleset_version = "3.2"
  domain_name           = var.domain_name
  key_vault_secret_id   = "${module.key_vault.key_vault_uri}secrets/sneakertail-cert"
}

resource "azurerm_role_assignment" "appgw_kv_secrets_user" {
  scope                = module.key_vault.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.app_gateway.identity_principal_id
}




# =============================================================================
# Module: Key Vault
# =============================================================================
# RBAC-enabled, private endpoint only. No public network access.
# =============================================================================

module "key_vault" {
  source = "./modules/key_vault"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  prefix              = var.prefix
  tags                = local.common_tags

  tenant_id           = data.azurerm_client_config.current.tenant_id
  pe_subnet_id        = module.networking.pe_subnet_id
  vnet_id             = module.networking.vnet_id
  private_dns_zone_id = module.networking.keyvault_private_dns_zone_id

  key_vault_admin_object_ids = [data.azurerm_client_config.current.object_id]
  runner_ip                  = var.runner_ip
}

# =============================================================================
# Key Vault Secrets
# =============================================================================

resource "azurerm_key_vault_secret" "user_portal_client_id" {
  name         = "user-portal-client-id"
  value        = var.user_portal_client_id
  key_vault_id = module.key_vault.key_vault_id

  # Only create the secret if the variable is provided
  count = var.user_portal_client_id != "" ? 1 : 0
}

# =============================================================================
# Module: AKS
# =============================================================================
# Private AKS cluster with AGIC, Standard_D2s_v5 node pools, ACR integration.
# =============================================================================

module "aks" {
  source = "./modules/aks"

  resource_group_name = azurerm_resource_group.main.name
  resource_group_id   = azurerm_resource_group.main.id
  location            = var.location
  prefix              = var.prefix
  tags                = local.common_tags

  # Node pool sizing — Standard_D2s_v5 default, override via variables
  default_node_pool_vm_size = var.system_node_vm_size
  user_node_pool_vm_size    = var.user_node_vm_size

  system_pool_node_count = var.system_pool_node_count
  system_pool_min_count  = var.system_pool_min_count
  system_pool_max_count  = var.system_pool_max_count

  user_pool_node_count = var.user_pool_node_count
  user_pool_min_count  = var.user_pool_min_count
  user_pool_max_count  = var.user_pool_max_count

  # Networking
  aks_subnet_id     = module.networking.aks_subnet_id
  aks_api_subnet_id = module.networking.aks_api_subnet_id
  appgw_id          = module.app_gateway.app_gateway_id
  appgw_subnet_id   = module.networking.appgw_subnet_id

  # ACR private endpoint
  pe_subnet_id            = module.networking.pe_subnet_id
  vnet_id                 = module.networking.vnet_id
  aks_private_dns_zone_id = module.networking.aks_private_dns_zone_id
  acr_private_dns_zone_id = module.networking.acr_private_dns_zone_id
  acr_name                = var.acr_name
}


# =============================================================================
# Module: Function App
# =============================================================================
# Premium EP1, VNet-integrated, User-Assigned Managed Identity for AWS OIDC.
# Triggered by Azure Storage Queue messages from the student-service.
# =============================================================================

module "function_app" {
  source = "./modules/function_app"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  prefix              = var.prefix
  tags                = local.common_tags

  func_subnet_id            = module.networking.func_subnet_id
  pe_subnet_id              = module.networking.pe_subnet_id
  vnet_id                   = module.networking.vnet_id
  blob_private_dns_zone_id  = module.networking.blob_private_dns_zone_id
  queue_private_dns_zone_id = module.networking.queue_private_dns_zone_id
  web_private_dns_zone_id   = module.networking.web_private_dns_zone_id
  key_vault_id              = module.key_vault.key_vault_id
}

# =============================================================================
# Module: AI Foundry
# =============================================================================
# AI Foundry Hub, Project, and Azure OpenAI (GPT-4o deployment).
# All resources private, no public network access.
# =============================================================================

module "ai_foundry" {
  source = "./modules/ai_foundry"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  prefix              = var.prefix
  tags                = local.common_tags

  pe_subnet_id                  = module.networking.pe_subnet_id
  vnet_id                       = module.networking.vnet_id
  cognitive_private_dns_zone_id = module.networking.cognitive_private_dns_zone_id
  openai_private_dns_zone_id    = module.networking.openai_private_dns_zone_id

  key_vault_id       = module.key_vault.key_vault_id
  storage_account_id = module.function_app.storage_account_id
}

# =============================================================================
# Module: Jumpbox
# =============================================================================
# Secure management gateway VM for cluster administrators.
# =============================================================================

module "jumpbox" {
  source = "./modules/jumpbox"

  resource_group_name  = azurerm_resource_group.main.name
  location             = var.location
  prefix               = var.prefix
  tags                 = local.common_tags
  subnet_id            = module.networking.jumpbox_subnet_id
  key_vault_id         = module.key_vault.key_vault_id
  admin_ssh_public_key = var.admin_ssh_public_key
}


# =============================================================================
# Workload Identity & Pod Federation
# =============================================================================
resource "azurerm_user_assigned_identity" "workload" {
  name                = "${var.prefix}-workload-identity"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  tags                = local.common_tags
}

resource "azurerm_federated_identity_credential" "workload" {
  name                      = "${var.prefix}-workload-fed-cred"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = module.aks.aks_oidc_issuer_url
  user_assigned_identity_id = azurerm_user_assigned_identity.workload.id
  subject                   = "system:serviceaccount:${var.environment}:ctmp-workload-sa"
}

resource "azurerm_role_assignment" "workload_kv_secrets_user" {
  scope                = module.key_vault.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.workload.principal_id
}

# =============================================================================
# Module: Database
# =============================================================================
# Provisions Azure Database for PostgreSQL Flexible Server within private VNet.
# =============================================================================

module "database" {
  source = "./modules/database"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  prefix              = var.prefix
  tags                = local.common_tags

  pg_subnet_id = module.networking.pg_subnet_id
  vnet_id      = module.networking.vnet_id
  key_vault_id = module.key_vault.key_vault_id

  tenant_id                      = data.azurerm_client_config.current.tenant_id
  workload_identity_principal_id = azurerm_user_assigned_identity.workload.principal_id
  workload_identity_name         = azurerm_user_assigned_identity.workload.name
}


# =============================================================================
# DNS A Record — Point domain to App Gateway public IP
# =============================================================================
# After deployment, configure your domain registrar (GoDaddy) to delegate NS
# authority to the Azure DNS name servers output by this configuration.
# =============================================================================

resource "azurerm_dns_a_record" "appgw" {
  name                = "@"
  zone_name           = var.domain_name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 300
  records             = [module.app_gateway.public_ip_address]

  depends_on = [module.networking]
}

resource "azurerm_dns_a_record" "api" {
  name                = "api"
  zone_name           = var.domain_name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 300
  records             = [module.app_gateway.public_ip_address]

  depends_on = [module.networking]
}

resource "azurerm_dns_a_record" "argocd" {
  name                = "argocd"
  zone_name           = var.domain_name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 300
  records             = [module.app_gateway.public_ip_address]

  depends_on = [module.networking]
}

# =============================================================================
# Azure Monitor Diagnostic Settings
# =============================================================================
# Routes logs and metrics from AKS, App Gateway, Key Vault, and PostgreSQL
# to the central Log Analytics Workspace.
# =============================================================================

resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "${var.prefix}-aks-diag"
  target_resource_id         = module.aks.aks_cluster_id
  log_analytics_workspace_id = module.aks.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "appgw" {
  name                       = "${var.prefix}-appgw-diag"
  target_resource_id         = module.app_gateway.app_gateway_id
  log_analytics_workspace_id = module.aks.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "keyvault" {
  name                       = "${var.prefix}-kv-diag"
  target_resource_id         = module.key_vault.key_vault_id
  log_analytics_workspace_id = module.aks.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "database" {
  name                       = "${var.prefix}-db-diag"
  target_resource_id         = module.database.server_id
  log_analytics_workspace_id = module.aks.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}







