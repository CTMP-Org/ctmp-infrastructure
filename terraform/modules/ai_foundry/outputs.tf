

output "ai_services_id" {
  description = "Resource ID of the Azure AI Services (Cognitive) account."
  value       = azurerm_cognitive_account.main.id
}

output "ai_services_endpoint" {
  description = "Endpoint of the Azure AI Services account."
  value       = azurerm_cognitive_account.main.endpoint
}

output "ai_foundry_hub_id" {
  description = "Resource ID of the AI Foundry Hub."
  value       = azurerm_ai_foundry.hub.id
}

output "ai_foundry_project_id" {
  description = "Resource ID of the AI Foundry Project."
  value       = azurerm_ai_foundry_project.main.id
}

output "openai_deployment_name" {
  description = "Name of the GPT-4o OpenAI deployment."
  value       = azurerm_cognitive_deployment.gpt4o.name
}

output "ai_services_principal_id" {
  description = "Principal ID of the AI Services system-assigned identity."
  value       = azurerm_cognitive_account.main.identity[0].principal_id
}
