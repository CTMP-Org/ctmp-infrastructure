# =============================================================================
# Key Vault Module — Variables
# =============================================================================
# Inputs for provisioning a Key Vault with RBAC, private endpoint, and DNS.
# =============================================================================

variable "resource_group_name" {
  description = "Name of the resource group for the Key Vault."
  type        = string
}

variable "location" {
  description = "Azure region for the Key Vault."
  type        = string
  default     = "centralindia"
}

variable "prefix" {
  description = "Naming prefix for Key Vault resources."
  type        = string
}

variable "tags" {
  description = "Tags to apply to all Key Vault resources."
  type        = map(string)
  default     = {}
}

variable "tenant_id" {
  description = "Azure AD tenant ID for the Key Vault."
  type        = string
}

variable "sku_name" {
  description = "SKU tier for the Key Vault (standard or premium)."
  type        = string
  default     = "standard"
}

# -----------------------------------------------------------------------------
# Networking — Private Endpoint
# -----------------------------------------------------------------------------

variable "pe_subnet_id" {
  description = "Subnet ID where the Key Vault private endpoint will be placed."
  type        = string
}

variable "vnet_id" {
  description = "VNet ID for linking the private DNS zone."
  type        = string
}

variable "private_dns_zone_id" {
  description = "Resource ID of the privatelink.vaultcore.azure.net DNS zone."
  type        = string
}

# -----------------------------------------------------------------------------
# RBAC — Principal IDs that need Key Vault access
# -----------------------------------------------------------------------------

variable "key_vault_admin_object_ids" {
  description = "List of Azure AD object IDs granted Key Vault Administrator role."
  type        = list(string)
  default     = []
}

variable "key_vault_reader_object_ids" {
  description = "List of Azure AD object IDs granted Key Vault Secrets User role."
  type        = list(string)
  default     = []
}

variable "runner_ip" {
  description = "The public IP of the GitHub Actions runner to temporarily whitelist in the Key Vault firewall."
  type        = string
  default     = ""
}
