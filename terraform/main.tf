

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
    use_oidc             = true 
  }
}

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
  use_oidc = true 
}

provider "azapi" {}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

locals {
  common_tags = merge(var.tags, {
    project     = "ctmp3"
    environment = var.environment
    owner       = var.owner
    managed_by  = "terraform"
    region      = var.location
  })
}

module "networking" {
  source = "./modules/networking"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  prefix              = var.prefix
  tags                = local.common_tags

  vnet_address_space                        = var.vnet_address_space
  appgw_subnet_cidr                         = var.appgw_subnet_cidr
  aks_subnet_cidr                           = var.aks_subnet_cidr
  func_subnet_cidr                          = var.func_subnet_cidr
  pe_subnet_cidr                            = var.pe_subnet_cidr
  aks_api_subnet_cidr                       = var.aks_api_subnet_cidr
  jumpbox_subnet_cidr                       = var.jumpbox_subnet_cidr
  public_dns_zone_name                      = var.domain_name
  jumpbox_ssh_allowed_source_address_prefix = var.jumpbox_ssh_allowed_source_address_prefix
}

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

resource "azurerm_key_vault_secret" "user_portal_client_id" {
  name         = "user-portal-client-id"
  value        = var.user_portal_client_id
  key_vault_id = module.key_vault.key_vault_id

  
  count = var.user_portal_client_id != "" ? 1 : 0
}

module "aks" {
  source = "./modules/aks"

  resource_group_name = azurerm_resource_group.main.name
  resource_group_id   = azurerm_resource_group.main.id
  location            = var.location
  prefix              = var.prefix
  tags                = local.common_tags

  
  default_node_pool_vm_size = var.system_node_vm_size
  user_node_pool_vm_size    = var.user_node_vm_size

  system_pool_node_count = var.system_pool_node_count
  system_pool_min_count  = var.system_pool_min_count
  system_pool_max_count  = var.system_pool_max_count

  user_pool_node_count = var.user_pool_node_count
  user_pool_min_count  = var.user_pool_min_count
  user_pool_max_count  = var.user_pool_max_count

  
  aks_subnet_id     = module.networking.aks_subnet_id
  aks_api_subnet_id = module.networking.aks_api_subnet_id
  appgw_id          = module.app_gateway.app_gateway_id
  appgw_subnet_id   = module.networking.appgw_subnet_id

  
  pe_subnet_id            = module.networking.pe_subnet_id
  vnet_id                 = module.networking.vnet_id
  aks_private_dns_zone_id = module.networking.aks_private_dns_zone_id
  acr_private_dns_zone_id = module.networking.acr_private_dns_zone_id
  acr_name                = var.acr_name
  acr_default_action      = var.acr_default_action
}

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

resource "azurerm_role_assignment" "workload_openai_user" {
  scope                = module.ai_foundry.ai_services_id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_user_assigned_identity.workload.principal_id
}

resource "azurerm_key_vault_secret" "openai_endpoint" {
  name         = "openai-endpoint"
  value        = "https://${var.prefix}-ai-services.openai.azure.com/"
  key_vault_id = module.key_vault.key_vault_id
}

resource "azurerm_key_vault_secret" "openai_deployment_name" {
  name         = "openai-deployment-name"
  value        = module.ai_foundry.openai_deployment_name
  key_vault_id = module.key_vault.key_vault_id
}

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

