# =============================================================================
# AI Foundry Module — Main Configuration
# =============================================================================
# Provisions:
#   - Azure AI Services (cognitive account) with system-assigned identity
#   - AI Foundry Hub (workspace) linking Key Vault, Storage, and AI Services
#   - AI Foundry Project for organizing experiments and deployments
#   - GPT-4o model deployment via azurerm_ai_deployment
#   - Private endpoints for both Cognitive Services and OpenAI
#   - All resources have public_network_access disabled
#
# Architecture:
#   AI Services ← Private Endpoint (cognitiveservices)
#   AI Services ← Private Endpoint (openai)
#   AI Foundry Hub → references AI Services, Key Vault, Storage
#   AI Foundry Project → child of Hub
#   AI Deployment → GPT-4o model on AI Services
# =============================================================================

# =============================================================================
# Azure AI Services (Cognitive Account)
# =============================================================================
# This is the unified cognitive services resource that hosts OpenAI models,
# speech, vision, language, etc. We use it as the foundation for AI Foundry.
# =============================================================================

resource "azurerm_cognitive_account" "main" {
  name                  = "${var.prefix}-ai-services"
  location              = "swedencentral"
  resource_group_name   = var.resource_group_name
  kind                  = "AIServices"
  sku_name              = "S0"
  tags                  = var.tags
  custom_subdomain_name = "${var.prefix}-ai-services"

  # --- No public network access: private endpoint only ---
  public_network_access_enabled = false

  # --- System-assigned identity for RBAC ---
  identity {
    type = "SystemAssigned"
  }
}

# =============================================================================
# AI Foundry Hub
# =============================================================================
# The Hub is a workspace that connects AI Services with supporting resources
# (Key Vault for secrets, Storage for artifacts). It's the control plane
# for AI experiments and deployments.
# =============================================================================

resource "azurerm_ai_foundry" "hub" {
  name                = "${var.prefix}-ai-hub"
  location            = var.location
  resource_group_name = var.resource_group_name
  storage_account_id  = var.storage_account_id
  key_vault_id        = var.key_vault_id
  tags                = var.tags

  # --- No public network access ---
  public_network_access = "Disabled"

  identity {
    type = "SystemAssigned"
  }
}

# =============================================================================
# AI Foundry Project
# =============================================================================
# Projects are child resources of a Hub. They organize deployments, datasets,
# and experiments for a specific use case (e.g., the training portal chatbot).
# =============================================================================

resource "azurerm_ai_foundry_project" "main" {
  name               = "${var.prefix}-ai-project"
  location           = var.location
  ai_services_hub_id = azurerm_ai_foundry.hub.id
  tags               = var.tags

  identity {
    type = "SystemAssigned"
  }
}

# =============================================================================
# GPT-4o Model Deployment
# =============================================================================
# Deploys the gpt-4o model on the AI Services account. This is the primary
# LLM used by the training portal for AI-assisted learning features.
# =============================================================================

resource "azurerm_cognitive_deployment" "gpt4o" {
  name                 = "${var.prefix}-gpt4o"
  cognitive_account_id = azurerm_cognitive_account.main.id

  model {
    format  = "OpenAI"
    name    = var.openai_model_name
    version = var.openai_model_version
  }

  sku {
    name     = "Standard"
    capacity = var.openai_deployment_sku_capacity
  }
}

# =============================================================================
# Private Endpoints — Cognitive Services
# =============================================================================
# Provides private network access to the Cognitive Services API surface
# (non-OpenAI endpoints like speech, vision, etc.).
# =============================================================================

resource "azurerm_private_endpoint" "cognitive" {
  name                = "${var.prefix}-cognitive-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.prefix}-cognitive-psc"
    private_connection_resource_id = azurerm_cognitive_account.main.id
    is_manual_connection           = false
    subresource_names              = ["account"]
  }

  private_dns_zone_group {
    name                 = "cognitive-dns-zone-group"
    private_dns_zone_ids = [var.cognitive_private_dns_zone_id]
  }
}

# =============================================================================
# Private Endpoints — OpenAI
# =============================================================================
# Separate private endpoint for OpenAI-specific endpoints (completions,
# embeddings, DALL-E). Uses the privatelink.openai.azure.com DNS zone.
# =============================================================================

resource "azurerm_private_endpoint" "openai" {
  name                = "${var.prefix}-openai-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.prefix}-openai-psc"
    private_connection_resource_id = azurerm_cognitive_account.main.id
    is_manual_connection           = false
    subresource_names              = ["account"]
  }

  private_dns_zone_group {
    name                 = "openai-dns-zone-group"
    private_dns_zone_ids = [var.openai_private_dns_zone_id]
  }
}

# =============================================================================
# RBAC — AI Foundry Hub access to AI Services
# =============================================================================
# The Hub's managed identity needs Cognitive Services Contributor on the
# AI Services account to manage deployments and inference.
# =============================================================================

resource "azurerm_role_assignment" "hub_ai_services_contributor" {
  scope                = azurerm_cognitive_account.main.id
  role_definition_name = "Cognitive Services Contributor"
  principal_id         = azurerm_ai_foundry.hub.identity[0].principal_id
}

resource "azurerm_role_assignment" "hub_ai_services_openai_contributor" {
  scope                = azurerm_cognitive_account.main.id
  role_definition_name = "Cognitive Services OpenAI Contributor"
  principal_id         = azurerm_ai_foundry.hub.identity[0].principal_id
}
