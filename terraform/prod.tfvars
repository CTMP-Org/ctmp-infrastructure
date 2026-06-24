# =============================================================================
# Cross-Cloud GitOps Training Portal — Prod Variables
# Trigger: Production environment spinup
# =============================================================================

domain_name         = "training.sneakertail.online"
acr_name            = "ctmp3prodacr"
resource_group_name = "rg-ctmp3prod"
acr_default_action  = "Deny"
environment         = "prod"
prefix              = "ctmp3prod"
location            = "centralindia"
