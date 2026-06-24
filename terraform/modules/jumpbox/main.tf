# =============================================================================
# Jumpbox Module — Main Configuration
# =============================================================================
# Provisions a lightweight Linux Jumpbox VM inside the jumpbox subnet.
# This VM acts as the secure management gateway for cluster administrators
# to interact with the private AKS API server endpoint.
# =============================================================================

# --- Generate SSH Key dynamically if not provided ---
resource "tls_private_key" "jumpbox" {
  count     = var.admin_ssh_public_key == "" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_key_vault_secret" "jumpbox_private_key" {
  count        = var.admin_ssh_public_key == "" ? 1 : 0
  name         = "${var.prefix}-jumpbox-private-key"
  value        = tls_private_key.jumpbox[0].private_key_pem
  key_vault_id = var.key_vault_id
}


resource "azurerm_public_ip" "jumpbox" {
  name                = "${var.prefix}-jumpbox-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_network_interface" "jumpbox" {
  name                = "${var.prefix}-jumpbox-nic"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jumpbox.id
  }
}

# --- Automatically bootstrap VM with azure CLI, kubectl, and kubelogin ---
locals {
  custom_data = <<-EOF
  #!/bin/bash
  apt-get update -y
  apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

  # Install Azure CLI (One command installer)
  curl -fsSL 'https://azurecliprod.blob.core.windows.net/$root/deb_install.sh' | bash

  # Install CLI tools (Kubectl & Kubelogin) using native utility installer
  az aks install-cli
  EOF
}

resource "azurerm_linux_virtual_machine" "jumpbox" {
  name                            = "${var.prefix}-jumpbox"
  location                        = var.location
  resource_group_name             = var.resource_group_name
  size                            = "Standard_D2als_v6" # Cost-effective instance size for jumpbox operations
  admin_username                  = var.admin_username
  disable_password_authentication = true
  tags                            = var.tags

  network_interface_ids = [
    azurerm_network_interface.jumpbox.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key != "" ? var.admin_ssh_public_key : tls_private_key.jumpbox[0].public_key_openssh
  }

  os_disk {

    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = base64encode(local.custom_data)
}
