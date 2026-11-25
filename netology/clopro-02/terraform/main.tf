data "yandex_vpc_subnet" "public" {
  subnet_id = var.public_subnet_id
}

locals {
  http_port    = 80
  health_path  = "/health.php"
  picture_path = "${path.module}/../assets/picture.png"
  picture_url  = "https://storage.yandexcloud.net/${yandex_storage_object.picture.bucket}/${yandex_storage_object.picture.key}"
}

resource "yandex_iam_service_account" "storage" {
  folder_id = var.folder_id
  name      = "clopro-15-2-storage"
}

resource "yandex_resourcemanager_folder_iam_member" "storage" {
  folder_id = var.folder_id
  role      = "storage.admin"
  member    = "serviceAccount:${yandex_iam_service_account.storage.id}"
}

resource "yandex_iam_service_account_static_access_key" "storage" {
  service_account_id = yandex_iam_service_account.storage.id
  description        = "S3 credentials for the picture bucket; keep Terraform state private"

  depends_on = [yandex_resourcemanager_folder_iam_member.storage]
}

resource "yandex_storage_bucket" "pictures" {
  access_key    = yandex_iam_service_account_static_access_key.storage.access_key
  secret_key    = yandex_iam_service_account_static_access_key.storage.secret_key
  folder_id     = var.folder_id
  bucket        = var.bucket_name
  force_destroy = false

  anonymous_access_flags {
    read        = true
    list        = false
    config_read = false
  }
}

resource "yandex_storage_object" "picture" {
  access_key   = yandex_iam_service_account_static_access_key.storage.access_key
  secret_key   = yandex_iam_service_account_static_access_key.storage.secret_key
  bucket       = yandex_storage_bucket.pictures.bucket
  key          = "picture.png"
  source       = local.picture_path
  source_hash  = filemd5(local.picture_path)
  content_type = "image/png"
  acl          = "public-read"
}

resource "yandex_iam_service_account" "instance_group" {
  folder_id = var.folder_id
  name      = "clopro-15-2-instance-group"
}

resource "yandex_resourcemanager_folder_iam_member" "instance_group" {
  for_each = toset(["compute.editor", "load-balancer.editor"])

  folder_id = var.folder_id
  role      = each.key
  member    = "serviceAccount:${yandex_iam_service_account.instance_group.id}"
}

resource "yandex_vpc_security_group" "web" {
  name       = "clopro-15-2-web"
  folder_id  = var.folder_id
  network_id = data.yandex_vpc_subnet.public.network_id

  ingress {
    description    = "HTTP from clients"
    protocol       = "TCP"
    port           = local.http_port
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description       = "Network Load Balancer health checks"
    protocol          = "TCP"
    port              = local.http_port
    predefined_target = "loadbalancer_healthchecks"
  }

  ingress {
    description    = "SSH from the administrator network"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = [var.admin_cidr]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_compute_instance_group" "web" {
  name               = "clopro-15-2-lamp"
  folder_id          = var.folder_id
  service_account_id = yandex_iam_service_account.instance_group.id

  instance_template {
    name        = "clopro-15-2-lamp-{instance.index}"
    platform_id = "standard-v3"

    resources {
      cores  = 2
      memory = 2
    }

    boot_disk {
      mode = "READ_WRITE"
      initialize_params {
        image_id = var.lamp_image_id
        type     = "network-hdd"
        size     = 20
      }
    }

    network_interface {
      network_id         = data.yandex_vpc_subnet.public.network_id
      subnet_ids         = [var.public_subnet_id]
      security_group_ids = [yandex_vpc_security_group.web.id]
      nat                = true
    }

    metadata = {
      user-data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
        ssh_public_key = trimspace(var.ssh_public_key)
        index_php      = base64encode(replace(file("${path.module}/../app/index.php"), "__IMAGE_URL__", local.picture_url))
        health_php     = filebase64("${path.module}/../app/health.php")
      })
    }
  }

  allocation_policy {
    zones = [data.yandex_vpc_subnet.public.zone]
  }

  scale_policy {
    fixed_scale {
      size = 3
    }
  }

  deploy_policy {
    max_unavailable = 1
    max_expansion   = 0
    max_creating    = 3
    max_deleting    = 1
  }

  health_check {
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 5

    http_options {
      port = local.http_port
      path = local.health_path
    }
  }

  load_balancer {
    target_group_name = "clopro-15-2-lamp-targets"
    # The NLB is created after the IG exports its target group ID.
    # The IG's own HTTP autohealing check still runs independently.
    ignore_health_checks = true
  }

  depends_on = [
    yandex_resourcemanager_folder_iam_member.instance_group,
    yandex_storage_object.picture,
  ]
}

resource "yandex_lb_network_load_balancer" "web" {
  name      = "clopro-15-2-web"
  folder_id = var.folder_id
  type      = "external"

  listener {
    name        = "http"
    protocol    = "tcp"
    port        = local.http_port
    target_port = local.http_port

    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_compute_instance_group.web.load_balancer[0].target_group_id

    healthcheck {
      name                = "http-health"
      interval            = 5
      timeout             = 2
      healthy_threshold   = 2
      unhealthy_threshold = 2

      http_options {
        port = local.http_port
        path = local.health_path
      }
    }
  }
}
