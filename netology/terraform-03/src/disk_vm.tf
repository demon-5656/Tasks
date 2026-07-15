resource "yandex_compute_disk" "storage_extra" {
  count = var.storage_resources.extra_disks

  name = "storage-extra-${count.index + 1}"
  type = "network-hdd"
  zone = var.default_zone
  size = 1
}

resource "yandex_compute_instance" "storage_node" {
  name        = "storage"
  hostname    = "storage"
  platform_id = var.storage_resources.platform_id
  zone        = var.default_zone

  resources {
    cores         = var.storage_resources.cores
    memory        = var.storage_resources.memory
    core_fraction = var.storage_resources.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.image_id
      size     = var.storage_resources.boot_disk
      type     = "network-hdd"
    }
  }

  dynamic "secondary_disk" {
    for_each = yandex_compute_disk.storage_extra

    content {
      disk_id     = secondary_disk.value.id
      device_name = secondary_disk.value.name
      auto_delete = true
    }
  }

  scheduling_policy {
    preemptible = true
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.main.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.homework.id]
  }

  metadata = local.vm_metadata
}
