

variable "resource_group_name" {
  description = "Name of the resource group."
  type        = string
}

variable "location" {
  description = "Azure region for deployment."
  type        = string
}

variable "prefix" {
  description = "Naming prefix applied to resources."
  type        = string
}

variable "tags" {
  description = "Map of tags applied to every database resource."
  type        = map(string)
  default     = {}
}

variable "pg_subnet_id" {
  description = "Resource ID of the delegated PostgreSQL subnet."
  type        = string
}

variable "vnet_id" {
  description = "Resource ID of the virtual network."
  type        = string
}

variable "key_vault_id" {
  description = "Resource ID of the Key Vault."
  type        = string
}

variable "admin_username" {
  description = "Administrator login name for PostgreSQL."
  type        = string
  default     = "ctmpadmin"
}

variable "db_name" {
  description = "Name of the default database."
  type        = string
  default     = "ctmpdb"
}

variable "sku_name" {
  description = "PostgreSQL Flexible Server SKU name."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "tenant_id" {
  description = "Microsoft Entra ID Tenant ID."
  type        = string
}

variable "workload_identity_principal_id" {
  description = "Principal ID of the workload managed identity."
  type        = string
}

variable "workload_identity_name" {
  description = "Name of the workload managed identity."
  type        = string
}
