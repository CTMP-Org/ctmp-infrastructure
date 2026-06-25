

resource "azurerm_key_vault" "main" {
  name                = "${var.prefix}-kv"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = var.sku_name
  tags                = var.tags

  
  rbac_authorization_enabled = true

  
  purge_protection_enabled   = true
  soft_delete_retention_days = 90

  
  public_network_access_enabled = true

  
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    ip_rules       = var.runner_ip != "" ? [var.runner_ip] : []
  }
}

resource "azurerm_private_endpoint" "keyvault" {
  name                = "${var.prefix}-kv-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.prefix}-kv-psc"
    private_connection_resource_id = azurerm_key_vault.main.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "keyvault-dns-zone-group"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }
}

resource "azurerm_role_assignment" "kv_admin" {
  count                = length(var.key_vault_admin_object_ids)
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.key_vault_admin_object_ids[count.index]
}

resource "azurerm_role_assignment" "kv_reader" {
  count                = length(var.key_vault_reader_object_ids)
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.key_vault_reader_object_ids[count.index]
}

resource "time_sleep" "wait_for_firewall" {
  depends_on = [azurerm_key_vault.main]

  create_duration = "60s"
}
