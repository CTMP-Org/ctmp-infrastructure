# =============================================================================
# Certificate Renewal module — Variables
# =============================================================================

variable "acme_email" {
  description = "Email address for Let's Encrypt registration and renewal alerts."
  type        = string
  default     = "sinanlw95@gmail.com"
}

variable "certificate_name" {
  description = "The name of the certificate in Key Vault."
  type        = string
  default     = "sneakertail-cert"
}
