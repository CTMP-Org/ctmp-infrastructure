

variable "resource_group_name" {
  description = "Resource group for AI Foundry resources."
  type        = string
}

variable "location" {
  description = "Azure region for AI Foundry resources."
  type        = string
  default     = "centralindia"
}

variable "prefix" {
  description = "Naming prefix for AI Foundry resources."
  type        = string
}

variable "tags" {
  description = "Tags applied to all AI Foundry resources."
  type        = map(string)
  default     = {}
}

variable "pe_subnet_id" {
  description = "Subnet ID for AI Foundry private endpoints."
  type        = string
}

variable "vnet_id" {
  description = "VNet ID for linking private DNS zones."
  type        = string
}

variable "cognitive_private_dns_zone_id" {
  description = "Resource ID of the privatelink.cognitiveservices.azure.com DNS zone."
  type        = string
}

variable "openai_private_dns_zone_id" {
  description = "Resource ID of the privatelink.openai.azure.com DNS zone."
  type        = string
}

variable "openai_model_name" {
  description = "Model name to deploy (e.g., gpt-4o)."
  type        = string
  default     = "gpt-4o"
}

variable "openai_model_version" {
  description = "Version of the OpenAI model to deploy."
  type        = string
  default     = "2024-11-20"
}

variable "openai_deployment_sku_capacity" {
  description = "Capacity (in thousands of tokens per minute) for the OpenAI deployment."
  type        = number
  default     = 10
}

variable "key_vault_id" {
  description = "Resource ID of the Key Vault for AI Foundry Hub."
  type        = string
}

variable "storage_account_id" {
  description = "Resource ID of the storage account for AI Foundry Hub."
  type        = string
}

variable "application_insights_id" {
  description = "Resource ID of Application Insights for AI Foundry Hub (optional)."
  type        = string
  default     = ""
}
