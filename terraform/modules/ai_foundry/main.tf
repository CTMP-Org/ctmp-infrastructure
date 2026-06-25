

resource "azurerm_cognitive_account" "main" {
  name                  = "${var.prefix}-ai-services"
  location              = "swedencentral"
  resource_group_name   = var.resource_group_name
  kind                  = "AIServices"
  sku_name              = "S0"
  tags                  = var.tags
  custom_subdomain_name = "${var.prefix}-ai-services"

  
  public_network_access_enabled = false

  
  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_ai_foundry" "hub" {
  name                = "${var.prefix}-ai-hub"
  location            = var.location
  resource_group_name = var.resource_group_name
  storage_account_id  = var.storage_account_id
  key_vault_id        = var.key_vault_id
  tags                = var.tags

  
  public_network_access = "Disabled"

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_ai_foundry_project" "main" {
  name               = "${var.prefix}-ai-project"
  location           = var.location
  ai_services_hub_id = azurerm_ai_foundry.hub.id
  tags               = var.tags

  identity {
    type = "SystemAssigned"
  }
}

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
