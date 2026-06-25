# =============================================================================
# Cross-Cloud GitOps Training Portal — Dev Variables
# Trigger: Relative paths fix in infrastructure.yml
# =============================================================================

domain_name        = "dev.training.sneakertail.online"
acr_name           = "ctmp3acrdev"
acr_default_action = "Allow"
environment        = "dev"
prefix             = "ctmp3dev"
location           = "centralindia"

# Cost optimization: reduce AKS node counts for Dev
system_pool_node_count = 1
system_pool_min_count  = 1
system_pool_max_count  = 2

user_pool_node_count = 1
user_pool_min_count  = 1
user_pool_max_count  = 3