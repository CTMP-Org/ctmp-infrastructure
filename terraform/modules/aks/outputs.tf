

output "aks_cluster_id" {
  description = "Resource ID of the AKS cluster."
  value       = azurerm_kubernetes_cluster.main.id
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster."
  value       = azurerm_kubernetes_cluster.main.name
}

output "aks_cluster_fqdn" {
  description = "Private FQDN of the AKS cluster (only reachable via VNet)."
  value       = azurerm_kubernetes_cluster.main.private_fqdn
}

output "aks_kubelet_identity_object_id" {
  description = "Object ID of the AKS kubelet managed identity (for RBAC assignments)."
  value       = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

output "aks_kubelet_identity_client_id" {
  description = "Client ID of the AKS kubelet managed identity."
  value       = azurerm_kubernetes_cluster.main.kubelet_identity[0].client_id
}

output "aks_oidc_issuer_url" {
  description = "OIDC issuer URL for workload identity federation."
  value       = azurerm_kubernetes_cluster.main.oidc_issuer_url
}

output "kube_config_raw" {
  description = "Raw kubeconfig for the AKS cluster (sensitive)."
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}

output "kube_config_host" {
  description = "Kubernetes API server host from kubeconfig."
  value       = azurerm_kubernetes_cluster.main.kube_config[0].host
  sensitive   = true
}

output "client_certificate" {
  description = "Base64 encoded client certificate."
  value       = azurerm_kubernetes_cluster.main.kube_config[0].client_certificate
  sensitive   = true
}

output "client_key" {
  description = "Base64 encoded client key."
  value       = azurerm_kubernetes_cluster.main.kube_config[0].client_key
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64 encoded cluster CA certificate."
  value       = azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate
  sensitive   = true
}

output "acr_id" {
  description = "Resource ID of the Azure Container Registry."
  value       = azurerm_container_registry.main.id
}

output "acr_login_server" {
  description = "Login server URL of the ACR (e.g., ctmp3acr.azurecr.io)."
  value       = azurerm_container_registry.main.login_server
}

output "acr_name" {
  description = "Name of the Azure Container Registry."
  value       = azurerm_container_registry.main.name
}

output "aks_identity_principal_id" {
  description = "Principal ID of the AKS cluster user-assigned identity."
  value       = azurerm_user_assigned_identity.aks.principal_id
}

output "aks_node_resource_group" {
  description = "Name of the auto-generated node resource group."
  value       = azurerm_kubernetes_cluster.main.node_resource_group
}

output "agic_identity_object_id" {
  description = "Object ID of the AGIC managed identity."
  value       = azurerm_kubernetes_cluster.main.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics Workspace."
  value       = azurerm_log_analytics_workspace.aks.id
}

