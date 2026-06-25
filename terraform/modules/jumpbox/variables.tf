

variable "resource_group_name" {
  description = "Name of the resource group."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "prefix" {
  description = "Naming prefix."
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "subnet_id" {
  description = "Subnet ID of the jumpbox subnet."
  type        = string
}

variable "admin_username" {
  description = "Admin username for the VM."
  type        = string
  default     = "portaladmin"
}

variable "key_vault_id" {
  description = "Resource ID of Key Vault to store dynamically generated SSH private key."
  type        = string
}

variable "admin_ssh_public_key" {
  description = "Optional pre-generated public SSH key. If blank, a key will be dynamically generated."
  type        = string
  default     = ""
}

