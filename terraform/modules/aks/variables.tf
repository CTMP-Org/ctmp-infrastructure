# =============================================================================
# AKS Module — Variables
# =============================================================================
# Inputs for the private AKS cluster, node pools, ACR, and AGIC integration.
# =============================================================================

variable "resource_group_name" {
  description = "Resource group name for AKS and ACR resources."
  type        = string
}

variable "resource_group_id" {
  description = "The ID of the Resource Group created by the root module."
  type        = string
}

variable "location" {
  description = "Azure region for the AKS cluster."
  type        = string
  default     = "centralindia"
}

variable "prefix" {
  description = "Naming prefix for AKS resources."
  type        = string
}

variable "tags" {
  description = "Tags applied to all AKS resources."
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# AKS Cluster Configuration
# -----------------------------------------------------------------------------

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster. Use 'az aks get-versions' to list available versions."
  type        = string
  default     = "1.35.5"
}

variable "default_node_pool_vm_size" {
  description = "VM size for the default (system) node pool."
  type        = string
  default     = "Standard_D2als_v6"
}

variable "user_node_pool_vm_size" {
  description = "VM size for the user (workload) node pool."
  type        = string
  default     = "Standard_D2als_v6"
}

variable "system_pool_min_count" {
  description = "Minimum node count for the system pool autoscaler."
  type        = number
  default     = 1
}

variable "system_pool_max_count" {
  description = "Maximum node count for the system pool autoscaler."
  type        = number
  default     = 4
}

variable "system_pool_node_count" {
  description = "Initial node count for the system pool."
  type        = number
  default     = 1
}

variable "user_pool_min_count" {
  description = "Minimum node count for the user pool autoscaler."
  type        = number
  default     = 1
}

variable "user_pool_max_count" {
  description = "Maximum node count for the user pool autoscaler."
  type        = number
  default     = 6
}

variable "user_pool_node_count" {
  description = "Initial node count for the user pool."
  type        = number
  default     = 1
}

# -----------------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------------

variable "aks_subnet_id" {
  description = "Subnet ID for the AKS node pools (Azure CNI)."
  type        = string
}

variable "aks_api_subnet_id" {
  description = "Subnet ID for the AKS API server VNet integration."
  type        = string
}

variable "appgw_id" {
  description = "Resource ID of the Application Gateway for AGIC."
  type        = string
}

variable "appgw_subnet_id" {
  description = "Subnet ID of the Application Gateway (for AGIC)."
  type        = string
}

# -----------------------------------------------------------------------------
# ACR Configuration
# -----------------------------------------------------------------------------

variable "acr_name" {
  description = "Globally unique name for the Azure Container Registry (alphanumeric only)."
  type        = string
  default     = "ctmp3acr"
}

variable "pe_subnet_id" {
  description = "Subnet ID for the ACR private endpoint."
  type        = string
}

variable "vnet_id" {
  description = "VNet ID for linking ACR private DNS zone."
  type        = string
}

variable "acr_private_dns_zone_id" {
  description = "Resource ID of the privatelink.azurecr.io DNS zone (if pre-created). Leave empty to skip."
  type        = string
  default     = ""
}

variable "aks_private_dns_zone_id" {
  description = "Resource ID of the privatelink.centralindia.azmk8s.io DNS zone."
  type        = string
}

