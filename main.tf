terraform {
  required_version = ">= 0.13"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 2.26"
    }
  }
}

provider "azurerm" {
  skip_provider_registration = true
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

resource "azurerm_resource_group" "rg-atividadetfbraz" {
  name     = "atividadeterraform"
  location = "West Europe"
}

resource "azurerm_virtual_network" "vnet-atividadetfbraz" {
  name                = "vnet-atividadetfbraz"
  location            = azurerm_resource_group.rg-atividadetfbraz.location
  resource_group_name = azurerm_resource_group.rg-atividadetfbraz.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    environment = "Production"
    faculdade = "Impacta"
    turma = "ES23"
    membro1 = "FelipeBraz"
    membro2 = "ClarindoSal"
    membro3 = "NicolasBassi"
    membro4 = "SergioCastelo"
    membro5 = "SidãoFalcões"
  }
}

resource "azurerm_subnet" "sub-atividadetfbraz" {
  name                 = "sub-atividadetfbraz"
  resource_group_name  = azurerm_resource_group.rg-atividadetfbraz.name
  virtual_network_name = azurerm_virtual_network.vnet-atividadetfbraz.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "ip-atividadetfbraz" {
  name                = "ip-atividadetfbraz"
  resource_group_name = azurerm_resource_group.rg-atividadetfbraz.name
  location            = azurerm_resource_group.rg-atividadetfbraz.location
  allocation_method   = "Static"

  tags = {
    environment = "Production"
  }
}

resource "azurerm_network_security_group" "nsg-atividadetfbraz" {
  name                = "nsg-atividadetfbraz"
  location            = azurerm_resource_group.rg-atividadetfbraz.location
  resource_group_name = azurerm_resource_group.rg-atividadetfbraz.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "web"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Production"
  }
}

resource "azurerm_network_interface" "nic-atividadetfbraz" {
  name                = "nic-atividadetfbraz"
  location            = azurerm_resource_group.rg-atividadetfbraz.location
  resource_group_name = azurerm_resource_group.rg-atividadetfbraz.name

  ip_configuration {
    name                            = "ip-atividadetfbraz-nic"
    subnet_id                       = azurerm_subnet.sub-atividadetfbraz.id
    private_ip_address_allocation   = "Dynamic"
    public_ip_address_id            = azurerm_public_ip.ip-atividadetfbraz.id
  }
}

resource "azurerm_network_interface_security_group_association" "nic-nsg-atividadetfbraz" {
  network_interface_id      = azurerm_network_interface.nic-atividadetfbraz.id
  network_security_group_id = azurerm_network_security_group.nsg-atividadetfbraz.id
}

resource "azurerm_storage_account" "brazstorageaccount" {
    name                        = "storageaccountmyvm"
    resource_group_name         = azurerm_resource_group.rg-atividadetfbraz.name
    location                    = azurerm_resource_group.rg-atividadetfbraz.location
    account_tier                = "Standard"
    account_replication_type    = "LRS"
}

resource "azurerm_virtual_machine" "vm-atividadetfbraz" {
  name                  = "vm-atividadetfbraz"
  location              = azurerm_resource_group.rg-atividadetfbraz.location
  resource_group_name   = azurerm_resource_group.rg-atividadetfbraz.name
  network_interface_ids = [azurerm_network_interface.nic-atividadetfbraz.id]
  vm_size               = "Standard_DS1_v2"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "hostname"
    admin_username = var.user
    admin_password = var.pwd_user
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
  
  tags = {
    environment = "staging"
  }
}

data "azurerm_public_ip" "ip-atividadetfbraz"{
    name = azurerm_public_ip.ip-atividadetfbraz.name
    resource_group_name = azurerm_resource_group.rg-atividadetfbraz.name
}

resource "null_resource" "install-apache" {
  connection {
    type = "ssh"
    host = data.azurerm_public_ip.ip-atividadetfbraz.ip_address
    user = var.user
    password = var.pwd_user
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y apache2",
    ]
  }

  depends_on = [
    azurerm_virtual_machine.vm-atividadetfbraz
  ]
}

resource "null_resource" "upload-app" {
  connection {
    type = "ssh"
    host = data.azurerm_public_ip.ip-atividadetfbraz.ip_address
    user = var.user
    password = var.pwd_user
  }

  provisioner "file" {
    source = "app"
    destination = "/home/testeadmin"
  }

  depends_on = [
    azurerm_virtual_machine.vm-atividadetfbraz
  ]
}