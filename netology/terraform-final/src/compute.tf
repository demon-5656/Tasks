data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

resource "yandex_compute_instance" "app" {
  name        = "${var.app_name}-app"
  platform_id = var.vm_platform_id
  zone        = local.app_subnet.zone

  resources {
    cores         = var.vm_cores
    memory        = var.vm_memory
    core_fraction = var.vm_core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = var.vm_disk_size
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = local.app_subnet.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.app.id]
  }

  scheduling_policy {
    preemptible = true
  }

  metadata = {
    serial-port-enable = "1"
    user-data = templatefile("${path.module}/templates/cloud-init.yml", {
      ssh_public_key  = local.ssh_public_key
      app_repo        = var.app_repo
      app_name        = var.app_name
      registry_url    = local.registry_url
      image_tag       = var.image_tag
      public_base_url = local.public_base_url
      mysql_host      = yandex_mdb_mysql_cluster.app.host[0].fqdn
      mysql_database  = var.mysql_database
      mysql_user      = var.mysql_user
      mysql_password  = var.mysql_password
      jwt_secret      = var.jwt_secret
      smtp_host       = var.smtp_host
      smtp_port       = var.smtp_port
      smtp_secure     = var.smtp_secure
      smtp_user       = var.smtp_user
      smtp_password   = var.smtp_password
      smtp_from       = var.smtp_from
    })
  }
}
