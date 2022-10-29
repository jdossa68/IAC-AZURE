terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=2.91.0"
    }
  }
}

provider "azurerm" {
  features {}
}

#crear resource group
resource "azurerm_resource_group" "rg_jdo" {
    name            = "rg_terraform"
    location        = "westeurope"
}

#crear vm
resource "azurerm_virtual_network" "vnet_jdo" {
    name                = "vnet_terraform"
    resource_group_name = azurerm_resource_group.rg_jdo.name
    location            = azurerm_resource_group.rg_jdo.location
    address_space       = ["10.1.1.0/24"]
}

#crear subnet
resource "azurerm_subnet" "subnet_jdo" {
    name                 = "subnet_terraform"
    resource_group_name  = azurerm_resource_group.rg_jdo.name
    virtual_network_name = azurerm_virtual_network.vnet_jdo.name
    address_prefixes     = ["10.1.1.0/25"]
}

# Crear ip publica
resource "azurerm_public_ip" "public_ip_jdo" {
  name                = "terraform_public_ip"
  location            = azurerm_resource_group.rg_jdo.location
  resource_group_name = azurerm_resource_group.rg_jdo.name
  allocation_method   = "Dynamic"
}

# Crear security group
resource "azurerm_network_security_group" "nsg_jdo" {
  name                = "terraform_nsg"
  location            = azurerm_resource_group.rg_jdo.location
  resource_group_name = azurerm_resource_group.rg_jdo.name

  security_rule {
    name                       = "Allow_SSH"
    priority                   = 500
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
    security_rule {
    name                       = "Allow_HTTP"
    priority                   = 400
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

#crear interface
resource "azurerm_network_interface" "if_jdo" {
  name                = "nic-vm1"
  location            = azurerm_resource_group.rg_jdo.location
  resource_group_name = azurerm_resource_group.rg_jdo.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet_jdo.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip_jdo.id
  }
}

# Asociar grupo de seguridad a interface
resource "azurerm_network_interface_security_group_association" "nsg_if_jdo" {
  network_interface_id      = azurerm_network_interface.if_jdo.id
  network_security_group_id = azurerm_network_security_group.nsg_jdo.id
}

# Crear llave ssh 
resource "tls_private_key" "key_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

#crear vm
resource "azurerm_linux_virtual_machine" "vm_jdo" {
    name                = "vm1"
    resource_group_name = azurerm_resource_group.rg_jdo.name
    location            = azurerm_resource_group.rg_jdo.location
    network_interface_ids = [azurerm_network_interface.if_jdo.id]      
    size                = "Standard_DS1_v2"

    source_image_reference {
      publisher = "Canonical"
      offer     = "UbuntuServer"
      sku       = "18.04-LTS"
      version   = "latest"
    }

    computer_name                   = "vm1"
    admin_username                  = "azureuser"
    admin_password                  = "Prueba1234*"
    disable_password_authentication = false

    admin_ssh_key {
      username   = "azureuser"
      public_key = tls_private_key.key_ssh.public_key_openssh
    }

    os_disk {
      caching              = "ReadWrite"
      storage_account_type = "Standard_LRS"
    }
}

output "public_ip_address" {
  value = azurerm_linux_virtual_machine.vm_jdo.public_ip_address
}

output "tls_private_key" {
  value     = tls_private_key.key_ssh.private_key_pem
  sensitive = true
  
}

