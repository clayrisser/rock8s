resource "tls_private_key" "node" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_resource_group" "cluster" {
  count    = var.purpose == "master" ? 1 : 0
  name     = "${local.cluster}-rg"
  location = var.location
  tags     = local.common_tags
}

data "azurerm_resource_group" "cluster" {
  count = var.purpose == "worker" ? 1 : 0
  name  = "${local.cluster}-rg"
}

data "azurerm_virtual_network" "lan" {
  name                = var.network.lan.name
  resource_group_name = var.network.lan.resource_group
}

data "azurerm_subnet" "lan" {
  name                 = "${var.network.lan.name}-subnet"
  virtual_network_name = data.azurerm_virtual_network.lan.name
  resource_group_name  = var.network.lan.resource_group
}

resource "azurerm_network_security_group" "nodes" {
  count               = var.purpose == "master" ? 1 : 0
  name                = "${local.cluster}-nodes-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.cluster[0].name
  tags                = local.common_tags

  security_rule {
    name                       = "${local.cluster}-allow-lan-in"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  dynamic "security_rule" {
    for_each = local.has_gateway ? [] : [1]
    content {
      name                       = "${local.cluster}-allow-ssh-in"
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }

  security_rule {
    name                       = "${local.cluster}-allow-egress"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

data "azurerm_network_security_group" "nodes" {
  count               = var.purpose == "worker" ? 1 : 0
  name                = "${local.cluster}-nodes-nsg"
  resource_group_name = data.azurerm_resource_group.cluster[0].name
}

resource "azurerm_subnet_network_security_group_association" "lan" {
  count                     = var.purpose == "master" ? 1 : 0
  subnet_id                 = data.azurerm_subnet.lan.id
  network_security_group_id = azurerm_network_security_group.nodes[0].id
}

resource "azurerm_public_ip" "nodes" {
  count               = length(local.node_configs)
  name                = "${local.node_configs[count.index].name}-pip"
  location            = var.location
  resource_group_name = local.rg_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = merge(local.common_tags, { node = local.node_configs[count.index].name })
}

resource "azurerm_network_interface" "nodes" {
  count               = length(local.node_configs)
  name                = "${local.node_configs[count.index].name}-nic"
  location            = var.location
  resource_group_name = local.rg_name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = local.subnet_id
    private_ip_address_allocation = local.node_configs[count.index].ipv4 != null ? "Static" : "Dynamic"
    private_ip_address            = local.node_configs[count.index].ipv4
    public_ip_address_id          = azurerm_public_ip.nodes[count.index].id
  }

  tags = merge(local.common_tags, { node = local.node_configs[count.index].name })
}

resource "azurerm_linux_virtual_machine" "nodes" {
  count                           = length(local.node_configs)
  name                            = local.node_configs[count.index].name
  location                        = var.location
  resource_group_name             = local.rg_name
  size                            = local.node_configs[count.index].server_type
  admin_username                  = "rock8s"
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.nodes[count.index].id,
  ]

  admin_ssh_key {
    username   = "rock8s"
    public_key = tls_private_key.node.public_key_openssh
  }

  os_disk {
    name                 = "${local.node_configs[count.index].name}-os"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = local.azure_image[coalesce(local.node_configs[count.index].image, var.image)].publisher
    offer     = local.azure_image[coalesce(local.node_configs[count.index].image, var.image)].offer
    sku       = local.azure_image[coalesce(local.node_configs[count.index].image, var.image)].sku
    version   = local.azure_image[coalesce(local.node_configs[count.index].image, var.image)].version
  }

  custom_data = base64encode(local.cloud_init)

  tags = merge(local.common_tags, { node = local.node_configs[count.index].name })

  lifecycle {
    ignore_changes = [
      custom_data,
      source_image_reference,
    ]
  }

  depends_on = [
    azurerm_network_interface.nodes,
  ]
}
