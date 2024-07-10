resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

locals {
  ssh_public_key  = tls_private_key.key.public_key_openssh
  ssh_private_key = tls_private_key.key.private_key_pem
}


resource "azurerm_public_ip" "pip" {
  name                = "webserver-public-ip"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "nic" {
  name                = "${var.name}-nic"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.subnet.id
    public_ip_address_id          = azurerm_public_ip.pip.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_ssh_public_key" "ssh" {
  name                = "${var.name}-ssh"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  public_key          = local.ssh_public_key
}

resource "azurerm_virtual_machine" "vm" {

  connection {
    type        = "ssh"
    host        = azurerm_public_ip.pip.ip_address
    user        = "adminuser"
    private_key = local.ssh_private_key

  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update"
    ]
  }

  name                  = var.name
  location              = data.azurerm_resource_group.rg.location
  resource_group_name   = data.azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  vm_size               = "Standard_B1ls"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  storage_os_disk {
    name              = "${var.name}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = var.name
    admin_username = "adminuser"
    admin_password = random_password.password.result
  }

  os_profile_linux_config {
    disable_password_authentication = false
    ssh_keys {
      path     = "/home/adminuser/.ssh/authorized_keys"
      key_data = local.ssh_public_key
    }
  }


}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "_%@"

}

output "ip_address" {
  value = azurerm_public_ip.pip.ip_address
}