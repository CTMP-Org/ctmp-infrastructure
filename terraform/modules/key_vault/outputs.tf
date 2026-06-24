# =============================================================================
# Key Vault Module — Outputs
# =============================================================================

output "key_vault_id" {
  description = "Resource ID of the Key Vault."
  value       = azurerm_key_vault.main.id
  depends_on  = [time_sleep.wait_for_firewall]
}

output "key_vault_name" {
  description = "Name of the Key Vault."
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault (https://<name>.vault.azure.net/)."
  value       = azurerm_key_vault.main.vault_uri
  depends_on  = [time_sleep.wait_for_firewall]
}

output "private_endpoint_id" {
  description = "Resource ID of the Key Vault private endpoint."
  value       = azurerm_private_endpoint.keyvault.id
}
