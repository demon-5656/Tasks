resource "yandex_compute_instance" "web_nodes" {
  count = var.web_count

  name        = "web-${count.index + 1}"
  hostname    = "web-${count.index + 1}"
  platform_id = var.web_resources.platform_id
  zone        = var.default_zone

  depends_on = [
    yandex_compute_instance.database_nodes
  ]

  resources {
    cores         = var.web_resources.cores
    memory        = var.web_resources.memory
    core_fraction = var.web_resources.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.image_id
      size     = var.web_resources.disk_size
      type     = var.web_resources.disk_type
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
