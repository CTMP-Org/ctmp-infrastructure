

variable "resource_group_name" {
  description = "Resource group for the Application Gateway resources."
  type        = string
}

variable "location" {
  description = "Azure region for the Application Gateway."
  type        = string
  default     = "centralindia"
}

variable "prefix" {
  description = "Naming prefix for Application Gateway resources."
  type        = string
}

variable "tags" {
  description = "Tags applied to all Application Gateway resources."
  type        = map(string)
  default     = {}
}

variable "appgw_subnet_id" {
  description = "Subnet ID for the Application Gateway deployment."
  type        = string
}

variable "waf_mode" {
  description = "WAF mode: Detection or Prevention."
  type        = string
  default     = "Prevention"
}

variable "owasp_ruleset_version" {
  description = "OWASP rule set version for WAF policy."
  type        = string
  default     = "3.2"
}

variable "sku_name" {
  description = "SKU name for the Application Gateway."
  type        = string
  default     = "WAF_v2"
}

variable "sku_tier" {
  description = "SKU tier for the Application Gateway."
  type        = string
  default     = "WAF_v2"
}

variable "capacity" {
  description = "Instance count for the Application Gateway (when not using autoscale)."
  type        = number
  default     = 2
}

variable "domain_name" {
  description = "Domain name used in Application Gateway listener host names."
  type        = string
  default     = "training.sneakertail.online"
}

variable "key_vault_secret_id" {
  description = "The Secret ID of the SSL certificate in Key Vault."
  type        = string
}

