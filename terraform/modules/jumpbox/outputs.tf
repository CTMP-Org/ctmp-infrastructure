# =============================================================================
# Jumpbox Module — Outputs
# =============================================================================

output "jumpbox_public_ip" {
  description = "Public IP address of the Jumpbox VM."
  value       = azurerm_public_ip.jumpbox.ip_address
}

output "jumpbox_private_ip" {
  description = "Private IP address of the Jumpbox VM."
  value       = azurerm_network_interface.jumpbox.private_ip_address
}
