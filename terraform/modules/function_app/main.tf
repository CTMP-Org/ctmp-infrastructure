# =============================================================================
# Function App Module — Main Configuration
# =============================================================================
# Provisions:
#   - User-Assigned Managed Identity (for identity-based storage access)
#   - Storage Account with private endpoints (blob + queue)
#   - App Service Plan (Elastic Premium EP1)
#   - Linux Function App with:
#       • VNet integration via func-subnet
#       • Identity-based storage connection (no connection strings)
#       • Public network access disabled
#       • RBAC role assignments for storage access
#
# Security model:
#   - No storage account keys in app settings
#   - Managed Identity + RBAC replaces connection strings
#   - All traffic stays within the VNet via private endpoints and VNet integration
# =============================================================================

# =============================================================================
# User-Assigned Managed Identity
# =============================================================================
# A dedicated identity for the Function App. Using User-Assigned (vs System)
# allows pre-creating RBAC assignments before the Function App exists, and
# survives resource recreation without losing role bindings.
# =============================================================================

resource "azurerm_user_assigned_identity" "func" {
  name                = "${var.prefix}-func-identity"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# =============================================================================
# Storage Account — Function App Backing Store
# =============================================================================
# Azure Functions requires a storage account for triggers, bindings, and
# internal state (function keys, timer triggers, durable functions).
# This storage account has NO public access — only reachable via private endpoints.
# =============================================================================

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

  # Allow Azure services to bypass network rules (required for Function runtime).
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }
}

# =============================================================================
# Storage Private Endpoints — Blob & Queue
# =============================================================================
# The Function App runtime requires access to both blob and queue sub-resources.
# Each gets its own private endpoint in the pe-subnet with DNS zone groups
# for automatic A-record registration.
# =============================================================================

# --- Blob Private Endpoint ---
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

# --- Queue Private Endpoint ---
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

# =============================================================================
# App Service Plan — Elastic Premium (EP1)
# =============================================================================
# EP1 is the minimum tier that supports:
#   - VNet integration
#   - Private endpoints
#   - Always-on instances
#   - Premium scaling capabilities
# =============================================================================

resource "azurerm_service_plan" "func" {
  name                = "${var.prefix}-func-plan"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = var.service_plan_sku
  tags                = var.tags
}

# =============================================================================
# Linux Function App
# =============================================================================
# Key design decisions:
#   1. Identity-based storage connection: uses AzureWebJobsStorage__accountName
#      instead of a connection string — the managed identity authenticates.
#   2. VNet integration: routes all outbound traffic through func-subnet,
#      enabling access to private endpoints.
#   3. No public access: only reachable from within the VNet.
# =============================================================================

resource "azurerm_linux_function_app" "main" {
  name                = "${var.prefix}-func"
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.func.id
  tags                = var.tags

  # --- Network isolation ---
  public_network_access_enabled = false
  virtual_network_subnet_id     = var.func_subnet_id

  # --- Managed Identity: User-Assigned ---
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.func.id]
  }

  # --- Storage connection: identity-based (no secrets) ---
  # The Function runtime uses this identity + account name to access storage.
  storage_account_name          = azurerm_storage_account.func.name
  storage_uses_managed_identity = true

  # Key vault reference identity — specifies which identity to use for
  # resolving @Microsoft.KeyVault() app setting references.
  key_vault_reference_identity_id = azurerm_user_assigned_identity.func.id

  site_config {
    # --- Route all outbound through VNet ---
    vnet_route_all_enabled = true

    # --- Runtime stack ---
    application_stack {
      python_version = var.runtime_version
    }

    # --- Always ready for production ---
    always_on = true
  }

  app_settings = {
    # Identity-based storage connection — the runtime reads this and uses
    # the managed identity to authenticate to the storage account.
    "AzureWebJobsStorage__accountName" = azurerm_storage_account.func.name
    "AzureWebJobsStorage__credential"  = "managedidentity"
    "AzureWebJobsStorage__clientId"    = azurerm_user_assigned_identity.func.client_id

    # Use the user-assigned identity for all Azure SDK calls.
    "AZURE_CLIENT_ID" = azurerm_user_assigned_identity.func.client_id

    # Standard Function App settings.
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

  # Ensure private endpoints exist before the Function App tries to connect.
  depends_on = [
    azurerm_private_endpoint.func_blob,
    azurerm_private_endpoint.func_queue,
    azurerm_role_assignment.func_storage_blob,
    azurerm_role_assignment.func_storage_queue,
  ]
}

# =============================================================================
# RBAC Role Assignments — Storage Access
# =============================================================================
# The Function App's managed identity needs:
#   1. Storage Blob Data Owner — read/write blobs (function state, packages)
#   2. Storage Queue Data Contributor — read/write queue messages (triggers)
#   3. Storage Account Contributor — manage storage (lease blobs for locks)
# =============================================================================

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

# =============================================================================
# Function App Private Endpoint — Sites (Inbound Deployment)
# =============================================================================
# Allows the self-hosted runner (Jumpbox) and other VNet resources to reach the
# Function App's main site and Kudu SCM deployment endpoint privately.
# =============================================================================

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

