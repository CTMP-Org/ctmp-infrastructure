# =============================================================================
# Cross-Cloud GitOps Training Portal — Global Variables
# =============================================================================
# Central configuration for all modules. Override via terraform.tfvars or
# environment variables (TF_VAR_xxx).
# =============================================================================

# -----------------------------------------------------------------------------
# General
# -----------------------------------------------------------------------------

variable "resource_group_name" {
  description = "Name of the Azure Resource Group for all resources."
  type        = string
  default     = "rg-ctmp3"
}

variable "location" {
  description = "Azure region — globally forced to Central India."
  type        = string
  default     = "centralindia"

  validation {
    condition     = var.location == "centralindia"
    error_message = "All resources must be deployed to the centralindia region."
  }
}

variable "prefix" {
  description = "Naming prefix applied to all resources."
  type        = string
  default     = "ctmp3"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)."
  type        = string
  default     = "prod"
}

variable "tags" {
  description = "Additional tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "owner" {
  description = "The owner or team responsible for these resources."
  type        = string
  default     = "CTMP-Org"
}

# -----------------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------------

variable "vnet_address_space" {
  description = "Address space for the Virtual Network."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "appgw_subnet_cidr" {
  description = "CIDR for the Application Gateway subnet."
  type        = string
  default     = "10.0.4.0/24"
}

variable "aks_subnet_cidr" {
  description = "CIDR for the AKS node pool subnet (/22 for Azure CNI)."
  type        = string
  default     = "10.0.0.0/22"
}

variable "func_subnet_cidr" {
  description = "CIDR for the Function App VNet integration subnet."
  type        = string
  default     = "10.0.6.0/24"
}

variable "pe_subnet_cidr" {
  description = "CIDR for the Private Endpoints subnet."
  type        = string
  default     = "10.0.7.0/24"
}

variable "aks_api_subnet_cidr" {
  description = "CIDR for AKS API server VNet integration (/28 min)."
  type        = string
  default     = "10.0.8.0/28"
}

variable "jumpbox_subnet_cidr" {
  description = "CIDR for the Jumpbox subnet."
  type        = string
  default     = "10.0.9.0/24"
}

# -----------------------------------------------------------------------------
# Domain & DNS
# -----------------------------------------------------------------------------

variable "domain_name" {
  description = "Public domain name for the training portal DNS zone."
  type        = string
  default     = "training.sneakertail.online"
}

# -----------------------------------------------------------------------------
# AKS Compute
# -----------------------------------------------------------------------------

variable "system_node_vm_size" {
  description = "VM size for the AKS system (default) node pool."
  type        = string
  default     = "Standard_D2als_v6"
}

variable "user_node_vm_size" {
  description = "VM size for the AKS user (workload) node pool."
  type        = string
  default     = "Standard_D2als_v6"
}

# -----------------------------------------------------------------------------
# ACR
# -----------------------------------------------------------------------------

variable "acr_name" {
  description = "Globally unique name for Azure Container Registry (alphanumeric only)."
  type        = string
  default     = "ctmp3acr"
}

variable "acr_default_action" {
  description = "Default action for the ACR network rule set ('Allow' or 'Deny')."
  type        = string
  default     = "Deny"
}

variable "runner_ip" {
  description = "The public IP of the GitHub Actions runner to temporarily whitelist in the Key Vault firewall."
  type        = string
  default     = ""
}

variable "user_portal_client_id" {
  description = "Client ID of the ctmp3-user-portal App Registration used for MSAL login"
  type        = string
  default     = ""
}

variable "admin_ssh_public_key" {
  description = "SSH public key for access to the jumpbox VM. If empty, a key will be dynamically generated and uploaded to Key Vault."
  type        = string
  default     = ""
}

variable "jumpbox_ssh_allowed_source_address_prefix" {
  description = "Allowed IP range/CIDR or tag for SSH access to the jumpbox. Defaults to a restricted documentation range to prevent public exposure."
  type        = string
  default     = "203.0.113.0/24"
}

# --- AKS Node Pool Sizing ---

variable "system_pool_node_count" {
  description = "Target node count for the AKS system node pool."
  type        = number
  default     = 2
}

variable "system_pool_min_count" {
  description = "Minimum node count for the AKS system node pool."
  type        = number
  default     = 2
}

variable "system_pool_max_count" {
  description = "Maximum node count for the AKS system node pool."
  type        = number
  default     = 4
}

variable "user_pool_node_count" {
  description = "Target node count for the AKS user node pool."
  type        = number
  default     = 2
}

variable "user_pool_min_count" {
  description = "Minimum node count for the AKS user node pool."
  type        = number
  default     = 2
}

variable "user_pool_max_count" {
  description = "Maximum node count for the AKS user node pool."
  type        = number
  default     = 6
}






