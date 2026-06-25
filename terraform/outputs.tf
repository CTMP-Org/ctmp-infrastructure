

output "vnet_id" {
  description = "Resource ID of the Virtual Network."
  value       = module.networking.vnet_id
}

output "dns_name_servers" {
  description = <<-EOT
    Azure DNS name servers for the public zone.
    ACTION REQUIRED: Configure your domain registrar (GoDaddy) to delegate
    NS authority to these name servers.
  EOT
  value       = module.networking.public_dns_zone_name_servers
}

output "app_gateway_public_ip" {
  description = "Public IP address of the Application Gateway — the ONLY public IP."
  value       = module.app_gateway.public_ip_address
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster."
  value       = module.aks.aks_cluster_name
}

output "aks_cluster_fqdn" {
  description = "Private FQDN of the AKS cluster (reachable only via VNet)."
  value       = module.aks.aks_cluster_fqdn
}

output "aks_oidc_issuer_url" {
  description = "OIDC issuer URL for workload identity federation."
  value       = module.aks.aks_oidc_issuer_url
}

output "kube_config_raw" {
  description = "Raw kubeconfig for the AKS cluster."
  value       = module.aks.kube_config_raw
  sensitive   = true
}

output "acr_login_server" {
  description = "ACR login server URL (e.g., ctmp3acr.azurecr.io)."
  value       = module.aks.acr_login_server
}

output "key_vault_uri" {
  description = "URI of the Key Vault."
  value       = module.key_vault.key_vault_uri
}

output "key_vault_name" {
  description = "Name of the Key Vault."
  value       = module.key_vault.key_vault_name
}

output "function_app_name" {
  description = "Name of the Function App."
  value       = module.function_app.function_app_name
}

output "function_app_managed_identity_client_id" {
  description = "Client ID of the Function App's User-Assigned Managed Identity (used in AWS OIDC federation)."
  value       = module.function_app.function_app_identity_client_id
}

output "ai_services_endpoint" {
  description = "Endpoint of the Azure AI Services account."
  value       = module.ai_foundry.ai_services_endpoint
}

output "openai_deployment_name" {
  description = "Name of the GPT-4o deployment."
  value       = module.ai_foundry.openai_deployment_name
}

output "jumpbox_public_ip" {
  description = "Public IP address of the Jumpbox VM."
  value       = module.jumpbox.jumpbox_public_ip
}

output "resource_group_name" {
  description = "The name of the resource group containing all resources."
  value       = var.resource_group_name
}

output "domain_name" {
  description = "The public domain name of the portal."
  value       = var.domain_name
}

output "key_vault_id" {
  description = "The Resource ID of the Key Vault."
  value       = module.key_vault.key_vault_id
}

output "database_fqdn" {
  description = "Fully Qualified Domain Name of the PostgreSQL server."
  value       = module.database.server_fqdn
}

output "database_name" {
  description = "Name of the created database."
  value       = module.database.database_name
}

output "workload_identity_client_id" {
  description = "Client ID of the AKS Workload User-Assigned Managed Identity."
  value       = azurerm_user_assigned_identity.workload.client_id
}
