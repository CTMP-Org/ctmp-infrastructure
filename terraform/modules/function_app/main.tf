

resource "azurerm_user_assigned_identity" "func" {
  name                = "${var.prefix}-func-identity"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_storage_account" "func" {
  name                          = "${var.prefix}funcsa"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  account_kind                  = "StorageV2"
  min_tls_version               = "TLS1_2"
  public_network_access_enabled = false
  tags                          = var.tags

  
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }
}

resource "azurerm_private_endpoint" "func_blob" {
  name                = "${var.prefix}-func-blob-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.prefix}-func-blob-psc"
    private_connection_resource_id = azurerm_storage_account.func.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = "blob-dns-zone-group"
    private_dns_zone_ids = [var.blob_private_dns_zone_id]
  }
}

resource "azurerm_private_endpoint" "func_queue" {
  name                = "${var.prefix}-func-queue-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.prefix}-func-queue-psc"
    private_connection_resource_id = azurerm_storage_account.func.id
    is_manual_connection           = false
    subresource_names              = ["queue"]
  }

  private_dns_zone_group {
    name                 = "queue-dns-zone-group"
    private_dns_zone_ids = [var.queue_private_dns_zone_id]
  }
}

resource "azurerm_service_plan" "func" {
  name                = "${var.prefix}-func-plan"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = var.service_plan_sku
  tags                = var.tags
}

resource "azurerm_linux_function_app" "main" {
  name                = "${var.prefix}-func"
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.func.id
  tags                = var.tags

  
  public_network_access_enabled = false
  virtual_network_subnet_id     = var.func_subnet_id
  https_only                    = true

  
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.func.id]
  }

  
  
  storage_account_name          = azurerm_storage_account.func.name
  storage_uses_managed_identity = true

  
  
  key_vault_reference_identity_id = azurerm_user_assigned_identity.func.id

  site_config {
    
    vnet_route_all_enabled = true

    
    application_stack {
      python_version = var.runtime_version
    }

    
    always_on = true
  }

  app_settings = {
    
    
    "AzureWebJobsStorage__accountName" = azurerm_storage_account.func.name
    "AzureWebJobsStorage__credential"  = "managedidentity"
    "AzureWebJobsStorage__clientId"    = azurerm_user_assigned_identity.func.client_id

    
    "AZURE_CLIENT_ID" = azurerm_user_assigned_identity.func.client_id

    
    "FUNCTIONS_EXTENSION_VERSION" = "~4"
    "FUNCTIONS_WORKER_RUNTIME"    = var.runtime_name
    "WEBSITE_CONTENTOVERVNET"     = "1"
    "WEBSITE_RUN_FROM_PACKAGE"    = "1"
  }

  lifecycle {
    ignore_changes = [
      app_settings["AzureWebJobsStorage__accountName"],
      app_settings["FUNCTIONS_EXTENSION_VERSION"],
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
    ]
  }

  
  depends_on = [
    azurerm_private_endpoint.func_blob,
    azurerm_private_endpoint.func_queue,
    azurerm_role_assignment.func_storage_blob,
    azurerm_role_assignment.func_storage_queue,
  ]
}

resource "azurerm_role_assignment" "func_storage_blob" {
  scope                = azurerm_storage_account.func.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_user_assigned_identity.func.principal_id
}

resource "azurerm_role_assignment" "func_storage_queue" {
  scope                = azurerm_storage_account.func.id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_user_assigned_identity.func.principal_id
}

resource "azurerm_role_assignment" "func_storage_contributor" {
  scope                = azurerm_storage_account.func.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = azurerm_user_assigned_identity.func.principal_id
}

resource "azurerm_private_endpoint" "func_sites" {
  name                = "${var.prefix}-func-sites-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.prefix}-func-sites-psc"
    private_connection_resource_id = azurerm_linux_function_app.main.id
    is_manual_connection           = false
    subresource_names              = ["sites"]
  }

  private_dns_zone_group {
    name                 = "web-dns-zone-group"
    private_dns_zone_ids = [var.web_private_dns_zone_id]
  }
}

