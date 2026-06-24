# =============================================================================
# Networking Module — Outputs
# =============================================================================

# --- VNet ---
output "vnet_id" {
  description = "Resource ID of the Virtual Network."
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Name of the Virtual Network."
  value       = azurerm_virtual_network.main.name
}

# --- Subnet IDs ---
output "appgw_subnet_id" {
  description = "Resource ID of the Application Gateway subnet."
  value       = azurerm_subnet.appgw.id
}

output "aks_subnet_id" {
  description = "Resource ID of the AKS node pool subnet."
  value       = azurerm_subnet.aks.id
}

output "func_subnet_id" {
  description = "Resource ID of the Function App integration subnet."
  value       = azurerm_subnet.func.id
}

output "pe_subnet_id" {
  description = "Resource ID of the Private Endpoints subnet."
  value       = azurerm_subnet.pe.id
}

output "aks_api_subnet_id" {
  description = "Resource ID of the AKS API server VNet integration subnet."
  value       = azurerm_subnet.aks_api.id
}

output "jumpbox_subnet_id" {
  description = "Resource ID of the Jumpbox subnet."
  value       = azurerm_subnet.jumpbox.id
}

output "pg_subnet_id" {
  description = "Resource ID of the PostgreSQL delegated subnet."
  value       = azurerm_subnet.pg.id
}


# --- NSG IDs ---
output "appgw_nsg_id" {
  description = "Resource ID of the Application Gateway NSG."
  value       = azurerm_network_security_group.appgw.id
}

output "aks_nsg_id" {
  description = "Resource ID of the AKS NSG."
  value       = azurerm_network_security_group.aks.id
}

output "func_nsg_id" {
  description = "Resource ID of the Function App NSG."
  value       = azurerm_network_security_group.func.id
}

output "pe_nsg_id" {
  description = "Resource ID of the Private Endpoints NSG."
  value       = azurerm_network_security_group.pe.id
}

# --- Public DNS Zone ---
output "public_dns_zone_id" {
  description = "Resource ID of the public DNS zone."
  value       = azurerm_dns_zone.public.id
}

output "public_dns_zone_name_servers" {
  description = "Name servers for the public DNS zone — delegate from your registrar."
  value       = azurerm_dns_zone.public.name_servers
}

# --- Private DNS Zone IDs ---
output "keyvault_private_dns_zone_id" {
  description = "Resource ID of the privatelink.vaultcore.azure.net zone."
  value       = azurerm_private_dns_zone.keyvault.id
}

output "blob_private_dns_zone_id" {
  description = "Resource ID of the privatelink.blob.core.windows.net zone."
  value       = azurerm_private_dns_zone.blob.id
}

output "queue_private_dns_zone_id" {
  description = "Resource ID of the privatelink.queue.core.windows.net zone."
  value       = azurerm_private_dns_zone.queue.id
}

output "aks_private_dns_zone_id" {
  description = "Resource ID of the privatelink.centralindia.azmk8s.io zone."
  value       = azurerm_private_dns_zone.aks.id
}

output "cognitive_private_dns_zone_id" {
  description = "Resource ID of the privatelink.cognitiveservices.azure.com zone."
  value       = azurerm_private_dns_zone.cognitive.id
}

output "openai_private_dns_zone_id" {
  description = "Resource ID of the privatelink.openai.azure.com zone."
  value       = azurerm_private_dns_zone.openai.id
}

output "web_private_dns_zone_id" {
  description = "Resource ID of the privatelink.azurewebsites.net zone."
  value       = azurerm_private_dns_zone.web.id
}

output "acr_private_dns_zone_id" {
  description = "Resource ID of the privatelink.azurecr.io zone."
  value       = azurerm_private_dns_zone.acr.id
}

