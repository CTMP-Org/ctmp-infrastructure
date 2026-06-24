# =============================================================================
# Networking Module — Main Configuration
# =============================================================================
# Creates the foundational network layer:
#   - Virtual Network (10.0.0.0/16) with 5 purpose-built subnets
#   - 4 NSGs with zero-trust security rules (standalone rule resources)
#   - 1 Public DNS Zone for external resolution
#   - 6 Private DNS Zones for private endpoint resolution
#   - Subnet-NSG associations and subnet delegations
#
# CIDR Plan:
#   appgw-subnet:   10.0.1.0/24   — Application Gateway (only public-facing)
#   aks-subnet:     10.0.2.0/22   — AKS node pools (1024 IPs for Azure CNI)
#   func-subnet:    10.0.6.0/24   — Function App VNet integration
#   pe-subnet:      10.0.7.0/24   — Private Endpoints for all PaaS services
#   aks-api-subnet: 10.0.8.0/28   — AKS API server VNet integration
# =============================================================================

# =============================================================================
# Virtual Network
# =============================================================================

resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

# =============================================================================
# Subnets
# =============================================================================

# Application Gateway subnet — must NOT have any delegation.
resource "azurerm_subnet" "appgw" {
  name                 = "${var.prefix}-appgw-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.appgw_subnet_cidr]
}

# AKS node pool subnet — sized /22 for Azure CNI (up to 1024 pods/nodes).
resource "azurerm_subnet" "aks" {
  name                 = "${var.prefix}-aks-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.aks_subnet_cidr]
}

# Function App integration subnet — delegated to Microsoft.Web/serverFarms.
resource "azurerm_subnet" "func" {
  name                 = "${var.prefix}-func-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.func_subnet_cidr]

  delegation {
    name = "func-delegation"

    service_delegation {
      name = "Microsoft.Web/serverFarms"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action",
      ]
    }
  }
}

# Private Endpoints subnet — used by Key Vault, ACR, Storage, AI Services.
resource "azurerm_subnet" "pe" {
  name                 = "${var.prefix}-pe-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.pe_subnet_cidr]
}

# AKS API server VNet integration — minimum /28 for API server delegation.
resource "azurerm_subnet" "aks_api" {
  name                 = "${var.prefix}-aks-api-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.aks_api_subnet_cidr]

  delegation {
    name = "aks-api-delegation"

    service_delegation {
      name = "Microsoft.ContainerService/managedClusters"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

# Jumpbox subnet — for administrator connectivity to AKS
resource "azurerm_subnet" "jumpbox" {
  name                 = "${var.prefix}-jumpbox-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.jumpbox_subnet_cidr]
}

# PostgreSQL Flexible Server delegated subnet
resource "azurerm_subnet" "pg" {
  name                 = "${var.prefix}-pg-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.pg_subnet_cidr]

  delegation {
    name = "pg-delegation"

    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}


# =============================================================================
# Network Security Groups
# =============================================================================
# Zero-trust approach: define the NSG shell, then attach standalone rules.
# This avoids inline security_rule blocks and supports AGIC rule injection.
# =============================================================================

resource "azurerm_network_security_group" "appgw" {
  name                = "${var.prefix}-appgw-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_network_security_group" "aks" {
  name                = "${var.prefix}-aks-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_network_security_group" "func" {
  name                = "${var.prefix}-func-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_network_security_group" "pe" {
  name                = "${var.prefix}-pe-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_network_security_group" "jumpbox" {
  name                = "${var.prefix}-jumpbox-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_network_security_rule" "jumpbox_allow_ssh" {
  name                        = "Allow-SSH"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = var.jumpbox_ssh_allowed_source_address_prefix
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.jumpbox.name
}


# =============================================================================
# NSG Rules — Application Gateway
# =============================================================================
# The App Gateway requires:
#   1. Internet → 80/443 for public HTTP/HTTPS traffic
#   2. GatewayManager → 65200-65535 for Azure infrastructure probes
#   3. AzureLoadBalancer → Any for health probes
# =============================================================================

resource "azurerm_network_security_rule" "appgw_allow_http_internet" {
  name                        = "Allow-HTTP-Internet"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.appgw.name
}

resource "azurerm_network_security_rule" "appgw_allow_https_internet" {
  name                        = "Allow-HTTPS-Internet"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.appgw.name
}

resource "azurerm_network_security_rule" "appgw_allow_gateway_manager" {
  name                        = "Allow-GatewayManager"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "65200-65535"
  source_address_prefix       = "GatewayManager"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.appgw.name
}

resource "azurerm_network_security_rule" "appgw_allow_azure_lb" {
  name                        = "Allow-AzureLoadBalancer"
  priority                    = 130
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.appgw.name
}

# =============================================================================
# NSG Rules — AKS
# =============================================================================
# Zero-trust: deny all inbound, then explicitly allow only from App Gateway
# subnet on ports that backend services expose (80, 443, 8000-8006).
# Also allow AzureLoadBalancer for internal LB health probes.
# =============================================================================

resource "azurerm_network_security_rule" "aks_allow_http_from_appgw" {
  name                        = "Allow-HTTP-From-AppGW"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = var.appgw_subnet_cidr # 10.0.1.0/24
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.aks.name
}

resource "azurerm_network_security_rule" "aks_allow_https_from_appgw" {
  name                        = "Allow-HTTPS-From-AppGW"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = var.appgw_subnet_cidr
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.aks.name
}

resource "azurerm_network_security_rule" "aks_allow_backend_ports_from_appgw" {
  name                        = "Allow-Backend-Ports-From-AppGW"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8000-8006"
  source_address_prefix       = var.appgw_subnet_cidr
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.aks.name
}

resource "azurerm_network_security_rule" "aks_allow_outbound_github" {
  name                        = "Allow-Outbound-GitHub"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["22", "443"]
  source_address_prefix       = var.aks_subnet_cidr
  destination_address_prefix  = "Internet"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.aks.name
}

resource "azurerm_network_security_rule" "aks_allow_outbound_azure_cloud" {
  name                        = "Allow-Outbound-AzureCloud"
  priority                    = 110
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_ranges     = ["443", "9000", "1194"]
  source_address_prefix       = var.aks_subnet_cidr
  destination_address_prefix  = "AzureCloud"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.aks.name
}

# =============================================================================
# NSG Rules — Function App
# =============================================================================
# Only allow HTTPS from the AKS subnet. Deny everything else.
# =============================================================================

resource "azurerm_network_security_rule" "func_allow_https_from_aks" {
  name                        = "Allow-HTTPS-From-AKS"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = var.aks_subnet_cidr # 10.0.2.0/22
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.func.name
}

resource "azurerm_network_security_rule" "func_deny_all_inbound" {
  name                        = "Deny-All-Inbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.func.name
}

# =============================================================================
# NSG Rules — Private Endpoints
# =============================================================================
# Allow HTTPS from AKS and Function App subnets only. Deny all other inbound.
# =============================================================================

resource "azurerm_network_security_rule" "pe_allow_https_from_aks" {
  name                        = "Allow-HTTPS-From-AKS"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = var.aks_subnet_cidr
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.pe.name
}

resource "azurerm_network_security_rule" "pe_allow_https_from_func" {
  name                        = "Allow-HTTPS-From-Func"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = var.func_subnet_cidr
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.pe.name
}

resource "azurerm_network_security_rule" "pe_allow_https_from_jumpbox" {
  name                        = "Allow-HTTPS-From-Jumpbox"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = var.jumpbox_subnet_cidr
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.pe.name
}

resource "azurerm_network_security_rule" "pe_deny_all_inbound" {
  name                        = "Deny-All-Inbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.pe.name
}

# =============================================================================
# Subnet ↔ NSG Associations
# =============================================================================

resource "azurerm_subnet_network_security_group_association" "appgw" {
  subnet_id                 = azurerm_subnet.appgw.id
  network_security_group_id = azurerm_network_security_group.appgw.id
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

resource "azurerm_subnet_network_security_group_association" "func" {
  subnet_id                 = azurerm_subnet.func.id
  network_security_group_id = azurerm_network_security_group.func.id
}

resource "azurerm_subnet_network_security_group_association" "pe" {
  subnet_id                 = azurerm_subnet.pe.id
  network_security_group_id = azurerm_network_security_group.pe.id
}

resource "azurerm_subnet_network_security_group_association" "jumpbox" {
  subnet_id                 = azurerm_subnet.jumpbox.id
  network_security_group_id = azurerm_network_security_group.jumpbox.id
}


# =============================================================================
# Public DNS Zone
# =============================================================================
# Authoritative public DNS for the training portal. After deployment, delegate
# the NS records from your domain registrar to the Azure-assigned name servers.
# =============================================================================

resource "azurerm_dns_zone" "public" {
  name                = var.public_dns_zone_name
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# =============================================================================
# Private DNS Zones
# =============================================================================
# Each private DNS zone corresponds to an Azure PaaS service's private link
# FQDN. They are linked to the VNet so that resources within the VNet can
# resolve private endpoint IPs automatically.
# =============================================================================

resource "azurerm_private_dns_zone" "keyvault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "queue" {
  name                = "privatelink.queue.core.windows.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "aks" {
  name                = "privatelink.centralindia.azmk8s.io"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "cognitive" {
  name                = "privatelink.cognitiveservices.azure.com"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "openai" {
  name                = "privatelink.openai.azure.com"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "web" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "acr" {
  name                = "privatelink.azurecr.io"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}


# =============================================================================
# Private DNS Zone ↔ VNet Links
# =============================================================================
# Each private DNS zone must be linked to the VNet so internal resolution works.
# Registration is disabled — records are managed by private endpoint DNS groups.
# =============================================================================

resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
  name                  = "${var.prefix}-keyvault-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                  = "${var.prefix}-blob-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "queue" {
  name                  = "${var.prefix}-queue-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.queue.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "aks" {
  name                  = "${var.prefix}-aks-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.aks.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "cognitive" {
  name                  = "${var.prefix}-cognitive-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.cognitive.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "openai" {
  name                  = "${var.prefix}-openai-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.openai.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "web" {
  name                  = "${var.prefix}-web-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.web.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr" {
  name                  = "${var.prefix}-acr-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.acr.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = var.tags
}

