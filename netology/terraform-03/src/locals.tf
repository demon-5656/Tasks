locals {
  ssh_key = file(pathexpand(var.ssh_public_key_path))

  vm_metadata = {
    serial-port-enable = "1"
    ssh-keys           = "ubuntu:${local.ssh_key}"
  }

  db_nodes = {
    for node in var.each_vm : node.vm_name => node
  }

  web_inventory = [
    for vm in yandex_compute_instance.web_nodes : {
      name        = vm.name
      external_ip = vm.network_interface[0].nat_ip_address
      fqdn        = vm.fqdn
    }
  ]

  database_inventory = [
    for vm in yandex_compute_instance.database_nodes : {
      name        = vm.name
      external_ip = vm.network_interface[0].nat_ip_address
      fqdn        = vm.fqdn
    }
  ]

  storage_inventory = [
    {
      name        = yandex_compute_instance.storage_node.name
      external_ip = yandex_compute_instance.storage_node.network_interface[0].nat_ip_address
      fqdn        = yandex_compute_instance.storage_node.fqdn
    }
  ]
}
