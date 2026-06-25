

resource "azurerm_public_ip" "appgw" {
  name                = "${var.prefix}-appgw-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "${var.prefix}-portal"
  tags                = var.tags
}

resource "azurerm_web_application_firewall_policy" "main" {
  name                = "${var.prefix}-waf-policy"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  
  policy_settings {
    enabled                     = true
    mode                        = var.waf_mode
    request_body_check          = true
    max_request_body_size_in_kb = 128
    file_upload_limit_in_mb     = 100
  }

  
  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = var.owasp_ruleset_version
    }
  }
}

locals {
  
  frontend_ip_config_name  = "${var.prefix}-appgw-feip"
  frontend_port_name_http  = "${var.prefix}-appgw-feport-http"
  frontend_port_name_https = "${var.prefix}-appgw-feport-https"
  listener_name            = "${var.prefix}-appgw-listener-placeholder"
  backend_pool_name        = "${var.prefix}-appgw-backend-placeholder"
  backend_http_settings    = "${var.prefix}-appgw-http-settings-placeholder"
  request_routing_rule     = "${var.prefix}-appgw-rule-placeholder"
}

resource "azurerm_user_assigned_identity" "appgw" {
  name                = "${var.prefix}-appgw-identity"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_application_gateway" "main" {
  name                = "${var.prefix}-appgw"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
  firewall_policy_id  = azurerm_web_application_firewall_policy.main.id

  
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.appgw.id]
  }

  
  sku {
    name = var.sku_name
    tier = var.sku_tier
  }

  autoscale_configuration {
    min_capacity = 1
    max_capacity = var.capacity
  }

  
  gateway_ip_configuration {
    name      = "${var.prefix}-appgw-ip-config"
    subnet_id = var.appgw_subnet_id
  }

  
  frontend_ip_configuration {
    name                 = local.frontend_ip_config_name
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  
  frontend_port {
    name = local.frontend_port_name_http
    port = 80
  }

  frontend_port {
    name = local.frontend_port_name_https
    port = 443
  }

  
  backend_address_pool {
    name = local.backend_pool_name
  }

  
  ssl_certificate {
    name                = "sneakertail-cert"
    key_vault_secret_id = var.key_vault_secret_id
  }

  
  backend_http_settings {
    name                  = local.backend_http_settings
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
  }

  
  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_config_name
    frontend_port_name             = local.frontend_port_name_http
    protocol                       = "Http"
  }

  
  request_routing_rule {
    name                       = local.request_routing_rule
    priority                   = 100
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_pool_name
    backend_http_settings_name = local.backend_http_settings
  }

  
  
  
  
  
  
  
  lifecycle {
    ignore_changes = [
      backend_address_pool,
      backend_http_settings,
      frontend_port,
      http_listener,
      probe,
      redirect_configuration,
      request_routing_rule,
      url_path_map,
      tags["managed-by-k8s-ingress"],
    ]
  }
}
