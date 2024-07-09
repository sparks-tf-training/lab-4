# Terraform and Provisioners

This lab will demonstrate how to use provisioners in Terraform to configure resources after they are created.

We will use both local-exec and remote-exec provisioners to customize the `webserver` virtual machine.


## Prerequisites

* Terraform installed on your machine.
* The Azure CLI logged in to your Azure account.
* A resource group in the `France Central` region.
* A virtual network and subnet in the resource group.
* A custom image named `webserver` in the resource group.

## Instructions

Create a new file named `main.tf` inside this directory. This file will contain your main Terraform configuration.

In your `main.tf` file, add the following code to configure the Azure provider:

```hcl
provider "azurerm" {
  features {}
  skip_provider_registration = true
}
```

Create a `variables.tf` file to define the variables used in your configuration:

```hcl
variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "name" {
  description = "The name of the virtual machine"
  type        = string
}

variable "subnet_id" {
  description = "The ID of the subnet"
  type        = string
}
```

In a `terraform.tfvars` file, set the values for the variables:

```hcl
resource_group_name = "terraform-training"
name                = "webserver"
subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/terraform-training/providers/Microsoft.Network/virtualNetworks/example-network/subnets/example-subnet"
```

Add the following code to your `main.tf` file to retrieve the resource group and subnet:

```hcl
data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

data "azurerm_subnet" "subnet" {
  name                 = var.vnet_subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = data.azurerm_resource_group.rg.name
}

data "azurerm_image" "webserver" {
  name                = var.image_name
  resource_group_name = data.azurerm_resource_group.rg.name
}

```

Create a `webserver.tf` file to define the virtual machine configuration:

```hcl
resource "azurerm_network_interface" "nic" {
  name                = "${var.name}-nic"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_virtual_machine" "vm" {
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

  os_profile_linux_config {
    disable_password_authentication = false
  }

}
```

Initialize the directory:

```sh
terraform init
```

Apply the configuration:

```sh
terraform apply
```

After the `terraform apply` command completes, verify that the resources have been created in the Azure portal.

You should see a new virtual machine named `webserver` with the NGINX web server installed.

We will now try to use Ansible to configure the virtual machine.

Create a new directory named `ansible` inside this directory. This directory will contain your Ansible playbook.

Create a new file named `playbook.yml` inside the `ansible` directory. This file will contain your Ansible playbook.

Add the following code to your `playbook.yml` file to install NGINX:

```yaml
---
- hosts: all
  become: true
  tasks:
    - name: Install NGINX
      apt:
        name: nginx
        state: present
```

Create a `provisioners.tf` file to define the Ansible provisioner:

```hcl
resource "null_resource" "ansible" {
  triggers = {
    always_run = timestamp()
  }

  connection {
    type        = "ssh"
    host        = azurerm_public_ip.vm.ip_address
    user        = "adminuser"
    password    = "P@ssw0rd1234!"
    agent       = false
    private_key = file("~/.ssh/id_rsa")
  }

  provisioner "local-exec" {
    command = "ansible-playbook -i '${azurerm_public_ip.vm.ip_address},' -u adminuser -k -e 'ansible_python_interpreter=/usr/bin/python3' playbook.yml"
    working_dir = "${path.module}/ansible"
  }
}
```

Add the following code to your `main.tf` file to retrieve the public IP address of the virtual machine:

```hcl
data "azurerm_public_ip" "vm" {
  name                = "${var.name}-public-ip"
  resource_group_name = data.azurerm_resource_group.rg.name
}
```

Apply the configuration:

```sh
terraform apply
```

After the `terraform apply` command completes, verify that the NGINX web server has been installed on the virtual machine.
