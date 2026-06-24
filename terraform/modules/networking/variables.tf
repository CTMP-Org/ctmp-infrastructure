# =============================================================================
# Networking Module — Variables
# =============================================================================
# Defines all input parameters for the VNet, subnets, NSGs, and DNS zones.
# =============================================================================

variable "resource_group_name" {
  description = "Name of the resource group where networking resources will be created."
  type        = string
}

variable "location" {
  description = "Azure region for all networking resources."
  type        = string
  default     = "centralindia"
}

variable "prefix" {
  description = "Naming prefix applied to all networking resources."
  type        = string
}

variable "tags" {
  description = "Map of tags applied to every networking resource."
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# VNet & Subnet CIDR Configuration
# -----------------------------------------------------------------------------

variable "vnet_address_space" {
  description = "Address space for the Virtual Network."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "appgw_subnet_cidr" {
  description = "CIDR block for the Application Gateway subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "aks_subnet_cidr" {
  description = "CIDR block for the AKS node pool subnet. Sized /22 for Azure CNI (1024 IPs)."
  type        = string
  default     = "10.0.2.0/22"
}

variable "func_subnet_cidr" {
  description = "CIDR block for the Function App VNet-integration subnet."
  type        = string
  default     = "10.0.6.0/24"
}

variable "pe_subnet_cidr" {
  description = "CIDR block for the Private Endpoints subnet."
  type        = string
  default     = "10.0.7.0/24"
}

variable "aks_api_subnet_cidr" {
  description = "CIDR block for AKS API server VNet integration (/28 minimum)."
  type        = string
  default     = "10.0.8.0/28"
}

variable "jumpbox_subnet_cidr" {
  description = "CIDR block for the Jumpbox subnet."
  type        = string
  default     = "10.0.9.0/24"
}

# -----------------------------------------------------------------------------
# DNS Configuration
# -----------------------------------------------------------------------------

variable "public_dns_zone_name" {
  description = "Public DNS zone name for external-facing services."
  type        = string
  default     = "training.sneakertail.online"
}

variable "pg_subnet_cidr" {
  description = "CIDR block for the PostgreSQL Flexible Server VNet-integrated subnet."
  type        = string
  default     = "10.0.10.0/24"
}

variable "jumpbox_ssh_allowed_source_address_prefix" {
  description = "Allowed IP range/CIDR or tag for SSH access to the jumpbox."
  type        = string
  default     = "203.0.113.0/24"
}


