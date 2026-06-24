# =============================================================================
# Function App Module — Outputs
# =============================================================================

output "function_app_id" {
  description = "Resource ID of the Linux Function App."
  value       = azurerm_linux_function_app.main.id
}

output "function_app_name" {
  description = "Name of the Linux Function App."
  value       = azurerm_linux_function_app.main.name
}

output "function_app_default_hostname" {
  description = "Default hostname of the Function App."
  value       = azurerm_linux_function_app.main.default_hostname
}

output "function_app_identity_principal_id" {
  description = "Principal ID of the User-Assigned Managed Identity."
  value       = azurerm_user_assigned_identity.func.principal_id
}

output "function_app_identity_client_id" {
  description = "Client ID of the User-Assigned Managed Identity."
  value       = azurerm_user_assigned_identity.func.client_id
}

output "function_app_identity_id" {
  description = "Resource ID of the User-Assigned Managed Identity."
  value       = azurerm_user_assigned_identity.func.id
}

output "storage_account_id" {
  description = "Resource ID of the Function App's backing storage account."
  value       = azurerm_storage_account.func.id
}

output "storage_account_name" {
  description = "Name of the Function App's backing storage account."
  value       = azurerm_storage_account.func.name
}

output "service_plan_id" {
  description = "Resource ID of the App Service Plan."
  value       = azurerm_service_plan.func.id
}
