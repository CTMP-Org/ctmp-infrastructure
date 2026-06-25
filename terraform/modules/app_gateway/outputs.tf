

output "app_gateway_id" {
  description = "Resource ID of the Application Gateway."
  value       = azurerm_application_gateway.main.id
}

output "app_gateway_name" {
  description = "Name of the Application Gateway."
  value       = azurerm_application_gateway.main.name
}

output "public_ip_id" {
  description = "Resource ID of the Application Gateway public IP."
  value       = azurerm_public_ip.appgw.id
}

output "public_ip_address" {
  description = "Public IP address of the Application Gateway — the ONLY public IP in the infrastructure."
  value       = azurerm_public_ip.appgw.ip_address
}

output "public_ip_fqdn" {
  description = "FQDN of the Application Gateway public IP (if DNS label configured)."
  value       = azurerm_public_ip.appgw.fqdn
}

output "waf_policy_id" {
  description = "Resource ID of the WAF policy."
  value       = azurerm_web_application_firewall_policy.main.id
}

output "identity_principal_id" {
  description = "Principal ID of the Application Gateway User-Assigned Managed Identity."
  value       = azurerm_user_assigned_identity.appgw.principal_id
}

output "identity_resource_id" {
  description = "Resource ID of the Application Gateway User-Assigned Managed Identity."
  value       = azurerm_user_assigned_identity.appgw.id
}

