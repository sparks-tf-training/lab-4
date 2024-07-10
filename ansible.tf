locals {
  ip = azurerm_public_ip.pip.ip_address
}
resource "null_resource" "ansible" {

  depends_on = [azurerm_virtual_machine.vm]
  triggers = {
    playbook   = file("${path.module}/ansible/playbook.yml")
    ip         = azurerm_public_ip.pip.ip_address
    machine_id = azurerm_virtual_machine.vm.id
  }

  provisioner "local-exec" {
    command     = <<EOF
        echo "[webserver]" > hosts
        echo "${local.ip}" >> hosts
        echo "" >> hosts
        echo "[webserver:vars]" >> hosts
        echo "ansible_ssh_common_args='-o StrictHostKeyChecking=no'" >> hosts
        echo "ansible_ssh_user=adminuser" >> hosts
        echo "ansible_ssh_pass=${random_password.password.result}" >> hosts
        EOF
    working_dir = "${path.module}/ansible"

  }

  provisioner "local-exec" {
    command     = "ansible-playbook -i hosts playbook.yml"
    working_dir = "${path.module}/ansible"
  }
}