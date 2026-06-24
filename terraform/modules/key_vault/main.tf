# =============================================================================
# Key Vault Module — Main Configuration
# =============================================================================
# Provisions an Azure Key Vault with:
#   - RBAC authorization (no access policies — all access via Azure RBAC)
#   - Soft-delete and purge protection enabled
#   - Private endpoint in the pe-subnet (no public network access)
#   - DNS zone group for automatic privatelink record registration
#   - Role assignments for admins and readers
# =============================================================================

# =============================================================================
# Key Vault
# =============================================================================

resource "azurerm_key_vault" "main" {
  name                = "${var.prefix}-kv"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = var.sku_name
  tags                = var.tags

  # --- RBAC-based access (no legacy access policies) ---
  rbac_authorization_enabled = true

  # --- Security hardening ---
  purge_protection_enabled   = true
  soft_delete_retention_days = 90

  # --- Network isolation: default deny, allow IP whitelisting ---
  public_network_access_enabled = true

  # Network ACLs default deny for defense-in-depth alongside the PE.
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    ip_rules       = var.runner_ip != "" ? [var.runner_ip] : []
  }
}

# =============================================================================
# Private Endpoint
# =============================================================================
# Places the Key Vault's private IP in the pe-subnet so only VNet-connected
# workloads can reach it. The DNS zone group ensures that
# <vault-name>.vault.azure.net resolves to this private IP within the VNet.
# =============================================================================

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

# =============================================================================
# RBAC Role Assignments
# =============================================================================
# Key Vault Administrator — full control over keys, secrets, and certificates.
# Assigned to operator/admin principals passed via variable.
# =============================================================================

resource "azurerm_role_assignment" "kv_admin" {
  count                = length(var.key_vault_admin_object_ids)
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.key_vault_admin_object_ids[count.index]
}

# Key Vault Secrets User — read-only access to secrets.
# Typically assigned to workload identities (AKS pods, Function Apps).
resource "azurerm_role_assignment" "kv_reader" {
  count                = length(var.key_vault_reader_object_ids)
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.key_vault_reader_object_ids[count.index]
}

# --- Delay downstream actions to allow firewall rules to propagate ---
resource "time_sleep" "wait_for_firewall" {
  depends_on = [azurerm_key_vault.main]

  create_duration = "60s"
}
