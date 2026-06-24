# =============================================================================
# AKS Module — Main Configuration
# =============================================================================
# Provisions:
#   - Private AKS cluster with Azure CNI and AGIC add-on
#   - System node pool (Standard_D2s_v5, 2 nodes, autoscale 2-4)
#   - User node pool (Standard_D2s_v5, 2 nodes, autoscale 2-6)
#   - Azure Container Registry (Premium SKU) with private endpoint
#   - AcrPull role assignment for the AKS kubelet identity
#   - Workload identity and OIDC issuer enabled for pod identity federation
#
# Network model: Azure CNI with dynamic IP allocation from aks-subnet.
# The API server uses VNet integration via aks-api-subnet for private access.
# =============================================================================

# =============================================================================
# AKS Managed Identity & Permissions
# =============================================================================
# A User-Assigned Managed Identity is required for private AKS cluster creation
# when integrating with a custom Private DNS Zone, so permissions can be assigned
# before the cluster attempts registration.
# =============================================================================

resource "azurerm_user_assigned_identity" "aks" {
  name                = "${var.prefix}-aks-identity"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_role_assignment" "aks_dns_contributor_pre" {
  scope                = var.aks_private_dns_zone_id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

# =============================================================================
# AKS Cluster
# =============================================================================

resource "azurerm_kubernetes_cluster" "main" {
  depends_on          = [azurerm_role_assignment.aks_dns_contributor_pre]
  name                = "${var.prefix}-aks"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "${var.prefix}-aks"
  kubernetes_version  = var.kubernetes_version
  tags                = var.tags

  # --- Private cluster: API server is NOT exposed to the internet ---
  private_cluster_enabled = true
  private_dns_zone_id     = var.aks_private_dns_zone_id

  # --- API server VNet integration (places API server in aks-api-subnet) ---
  api_server_access_profile {
    virtual_network_integration_enabled = true
    subnet_id                           = var.aks_api_subnet_id
  }

  # --- Cluster identity: UserAssigned managed identity ---
  # Required when deploying AKS with custom private DNS zone.
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  # --- Default (System) node pool ---
  # Runs critical system pods (CoreDNS, kube-proxy, metrics-server).
  # Tainted with CriticalAddonsOnly so user workloads land on the user pool.
  default_node_pool {
    name                 = "system"
    vm_size              = var.default_node_pool_vm_size
    vnet_subnet_id       = var.aks_subnet_id
    node_count           = var.system_pool_node_count
    auto_scaling_enabled = true
    min_count            = var.system_pool_min_count
    max_count            = var.system_pool_max_count
    os_disk_size_gb      = 128
    os_disk_type         = "Managed"
    type                 = "VirtualMachineScaleSets"
    zones                = ["1", "2"]

    # Only schedule system-critical pods on this pool.
    only_critical_addons_enabled = true

    # Upgrade settings for rolling node image upgrades.
    upgrade_settings {
      max_surge = "33%"
    }
  }

  # --- Network profile: Azure CNI for native VNet pod networking ---
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "calico"
    service_cidr        = "172.16.0.0/16"
    dns_service_ip      = "172.16.0.10"
    load_balancer_sku   = "standard"
  }

  # --- AGIC add-on: integrates with the pre-provisioned Application Gateway ---
  ingress_application_gateway {
    gateway_id = var.appgw_id
  }

  # --- Workload Identity: enables Azure AD pod identity federation ---
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # --- Key Vault Secrets Provider: installs Secrets Store CSI driver & Azure Key Vault provider ---
  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  # --- Azure Monitor: container insights ---
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.aks.id
  }

  # --- Auto-upgrade channel ---
  automatic_upgrade_channel = "patch"

  # --- Enable Role-Based Access Control ---
  role_based_access_control_enabled = true
}

# =============================================================================
# User Node Pool
# =============================================================================
# Dedicated pool for user workloads (training portal services).
# Autoscales from 2 to 6 nodes based on demand.
# =============================================================================

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.user_node_pool_vm_size
  vnet_subnet_id        = var.aks_subnet_id
  node_count            = var.user_pool_node_count
  auto_scaling_enabled  = true
  min_count             = var.user_pool_min_count
  max_count             = var.user_pool_max_count
  os_disk_size_gb       = 128
  os_disk_type          = "Managed"
  os_type               = "Linux"
  zones                 = ["1", "2"]
  mode                  = "User"
  tags                  = var.tags

  upgrade_settings {
    max_surge = "33%"
  }
}

# =============================================================================
# Log Analytics Workspace — Container Insights
# =============================================================================

resource "azurerm_log_analytics_workspace" "aks" {
  name                = "${var.prefix}-aks-logs"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# =============================================================================
# Azure Container Registry (Premium SKU)
# =============================================================================
# Premium is required for:
#   - Private endpoints (no public network access)
#   - Geo-replication (if needed later)
#   - Content trust and customer-managed keys
# =============================================================================

resource "azurerm_container_registry" "main" {
  name                          = var.acr_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku                           = "Premium"
  admin_enabled                 = false
  public_network_access_enabled = true
  tags                          = var.tags

  network_rule_set {
    default_action = "Deny"
  }
}




# =============================================================================
# AcrPull Role Assignment
# =============================================================================
# Grant the AKS kubelet identity the AcrPull role on the ACR so that nodes
# can pull container images without explicit docker login credentials.
# =============================================================================

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                            = azurerm_container_registry.main.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}

# =============================================================================
# AGIC — Network Contributor on App Gateway subnet
# =============================================================================
# The AGIC managed identity needs Network Contributor on the appgw subnet
# to configure the Application Gateway backend pools and routing.
# =============================================================================

resource "azurerm_role_assignment" "agic_appgw_subnet" {
  scope                = var.appgw_subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.main.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id
}

resource "azurerm_role_assignment" "agic_appgw_contributor" {
  scope                = var.appgw_id
  role_definition_name = "Contributor"
  principal_id         = azurerm_kubernetes_cluster.main.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id
}

# =============================================================================
# AKS — Network Contributor on AKS subnet
# =============================================================================
# The AKS cluster identity needs Network Contributor on the node subnet
# to manage network interfaces and route tables for Azure CNI.
# =============================================================================

resource "azurerm_role_assignment" "aks_network_contributor" {
  scope                = var.aks_subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

resource "azurerm_role_assignment" "aks_api_subnet_contributor" {
  scope                = var.aks_api_subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

# =============================================================================
# AGIC — Reader on Resource Group
# =============================================================================
# The AGIC managed identity needs Reader role on the resource group containing
# the Application Gateway and its Public IP address to read and resolve public
# IP properties.
# =============================================================================
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

resource "azurerm_role_assignment" "agic_rg_reader" {
  scope                = data.azurerm_resource_group.main.id
  role_definition_name = "Reader"
  principal_id         = azurerm_kubernetes_cluster.main.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id
}

# =============================================================================
# ArgoCD AKS Extension
# =============================================================================
# Deploys the managed ArgoCD extension on the AKS cluster.
# =============================================================================
resource "azurerm_kubernetes_cluster_extension" "argocd" {
  name           = "argocd"
  cluster_id     = azurerm_kubernetes_cluster.main.id
  extension_type = "Microsoft.ArgoCD"
  release_train  = "Preview"

  configuration_settings = {
    "azure.workloadIdentity.enabled"   = "false"
    "redis-ha.enabled"                 = "false"
    "configs.params.server\\.insecure" = "true"
  }

  depends_on = [
    azurerm_kubernetes_cluster_node_pool.user
  ]
}

resource "azurerm_private_endpoint" "acr" {
  name                = "${var.prefix}-acr-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.prefix}-acr-psc"
    private_connection_resource_id = azurerm_container_registry.main.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "acr-dns-zone-group"
    private_dns_zone_ids = [var.acr_private_dns_zone_id]
  }
}


