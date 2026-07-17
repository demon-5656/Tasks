output "vm_inventory" {
  value = {
    webservers = local.web_inventory
    databases  = local.database_inventory
    storage    = local.storage_inventory
  }
}

output "count_and_for_each_vms" {
  value = concat(
    [
      for vm in yandex_compute_instance.web_nodes : {
        name = vm.name
        id   = vm.id
        fqdn = vm.fqdn
      }
    ],
    [
      for vm in values(yandex_compute_instance.database_nodes) : {
        name = vm.name
        id   = vm.id
        fqdn = vm.fqdn
      }
    ]
  )
}

output "storage_disks" {
  value = [
    for disk in yandex_compute_disk.storage_extra : {
      name = disk.name
      id   = disk.id
      size = disk.size
    }
  ]
}
