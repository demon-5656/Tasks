resource "yandex_compute_instance" "database_nodes" {
  for_each = local.db_nodes

  name        = each.key
  hostname    = each.key
  platform_id = each.value.platform_id
  zone        = var.db_zone

  resources {
    cores         = each.value.cpu
    memory        = each.value.ram
    core_fraction = each.value.fraction
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.image_id
      size     = each.value.disk_volume
      type     = "network-hdd"
    }
  }

  scheduling_policy {
    preemptible = true
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.db.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.homework.id]
  }

  metadata = local.vm_metadata
}
