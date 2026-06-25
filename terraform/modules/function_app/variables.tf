

variable "resource_group_name" {
  description = "Resource group for Function App resources."
  type        = string
}

variable "location" {
  description = "Azure region for the Function App."
  type        = string
  default     = "centralindia"
}

variable "prefix" {
  description = "Naming prefix for Function App resources."
  type        = string
}

variable "tags" {
  description = "Tags applied to all Function App resources."
  type        = map(string)
  default     = {}
}

variable "func_subnet_id" {
  description = "Subnet ID for Function App VNet integration (must have delegation)."
  type        = string
}

variable "pe_subnet_id" {
  description = "Subnet ID for storage account private endpoints."
  type        = string
}

variable "vnet_id" {
  description = "VNet ID for linking private DNS zones."
  type        = string
}

variable "blob_private_dns_zone_id" {
  description = "Resource ID of the privatelink.blob.core.windows.net DNS zone."
  type        = string
}

variable "queue_private_dns_zone_id" {
  description = "Resource ID of the privatelink.queue.core.windows.net DNS zone."
  type        = string
}

variable "web_private_dns_zone_id" {
  description = "Resource ID of the privatelink.azurewebsites.net DNS zone."
  type        = string
}

variable "service_plan_sku" {
  description = "SKU for the Function App Service Plan (Elastic Premium tier recommended)."
  type        = string
  default     = "EP1"
}

variable "runtime_name" {
  description = "Function App runtime stack name."
  type        = string
  default     = "python"
}

variable "runtime_version" {
  description = "Function App runtime stack version."
  type        = string
  default     = "3.11"
}

variable "key_vault_id" {
  description = "Resource ID of the Key Vault for storing Function App secrets."
  type        = string
  default     = ""
}
