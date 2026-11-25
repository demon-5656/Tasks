mock_provider "yandex" {
  mock_data "yandex_vpc_subnet" {
    defaults = {
      zone       = "ru-central1-a"
      network_id = "enp-test-network"
    }
  }
}

variables {
  folder_id        = "b1g-test-folder"
  public_subnet_id = "e9b-test-public-subnet"
  bucket_name      = "clopro-15-2-mock-bucket"
  admin_cidr       = "203.0.113.10/32"
  ssh_public_key   = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG9mZmxpbmUtdGVzdC1rZXktbm90LWZvci1zc2gh mock-only"
}

run "lamp_group_and_public_picture_behind_nlb" {
  command = apply

  assert {
    condition = (
      yandex_resourcemanager_folder_iam_member.storage.role == "storage.admin" &&
      yandex_resourcemanager_folder_iam_member.storage.member == "serviceAccount:${yandex_iam_service_account.storage.id}" &&
      yandex_iam_service_account_static_access_key.storage.service_account_id == yandex_iam_service_account.storage.id &&
      yandex_storage_bucket.pictures.access_key == yandex_iam_service_account_static_access_key.storage.access_key &&
      yandex_storage_bucket.pictures.secret_key == yandex_iam_service_account_static_access_key.storage.secret_key &&
      yandex_storage_object.picture.access_key == yandex_iam_service_account_static_access_key.storage.access_key &&
      yandex_storage_object.picture.secret_key == yandex_iam_service_account_static_access_key.storage.secret_key
    )
    error_message = "S3 bucket and object must use the dedicated storage service account credentials."
  }

  assert {
    condition = (
      one(yandex_storage_bucket.pictures.anonymous_access_flags).read &&
      !one(yandex_storage_bucket.pictures.anonymous_access_flags).list &&
      !one(yandex_storage_bucket.pictures.anonymous_access_flags).config_read &&
      yandex_storage_object.picture.bucket == yandex_storage_bucket.pictures.bucket &&
      yandex_storage_object.picture.key == "picture.png" &&
      yandex_storage_object.picture.acl == "public-read" &&
      yandex_storage_object.picture.content_type == "image/png" &&
      yandex_storage_object.picture.source == "${path.module}/../assets/picture.png" &&
      yandex_storage_object.picture.source_hash == filemd5("${path.module}/../assets/picture.png") &&
      output.picture_url == "https://storage.yandexcloud.net/clopro-15-2-mock-bucket/picture.png"
    )
    error_message = "Object Storage must serve the local PNG anonymously without opening listing or configuration."
  }

  assert {
    condition = (
      yandex_compute_instance_group.web.instance_template[0].boot_disk[0].initialize_params[0].image_id == "fd827b91d99psvq5fjit" &&
      yandex_compute_instance_group.web.scale_policy[0].fixed_scale[0].size == 3 &&
      one(yandex_compute_instance_group.web.allocation_policy[0].zones) == "ru-central1-a" &&
      one(yandex_compute_instance_group.web.instance_template[0].network_interface[0].subnet_ids) == var.public_subnet_id &&
      yandex_compute_instance_group.web.instance_template[0].network_interface[0].network_id == data.yandex_vpc_subnet.public.network_id &&
      yandex_compute_instance_group.web.instance_template[0].network_interface[0].nat &&
      one(yandex_compute_instance_group.web.instance_template[0].network_interface[0].security_group_ids) == yandex_vpc_security_group.web.id
    )
    error_message = "The fixed group must use the assignment LAMP image and three public interfaces in the existing subnet."
  }

  assert {
    condition = (
      yandex_compute_instance_group.web.service_account_id == yandex_iam_service_account.instance_group.id &&
      toset(keys(yandex_resourcemanager_folder_iam_member.instance_group)) == toset(["compute.editor", "load-balancer.editor"]) &&
      alltrue([for grant in yandex_resourcemanager_folder_iam_member.instance_group : grant.member == "serviceAccount:${yandex_iam_service_account.instance_group.id}"])
    )
    error_message = "The group service account must have the Compute and NLB roles."
  }

  assert {
    condition = (
      length([for rule in yandex_vpc_security_group.web.ingress : rule if rule.protocol == "TCP" && rule.port == 80 && try(contains(rule.v4_cidr_blocks, "0.0.0.0/0"), false)]) == 1 &&
      length([for rule in yandex_vpc_security_group.web.ingress : rule if rule.protocol == "TCP" && rule.port == 80 && rule.predefined_target == "loadbalancer_healthchecks"]) == 1 &&
      [for rule in yandex_vpc_security_group.web.ingress : rule if rule.port == 22][0].protocol == "TCP" &&
      toset(one([for rule in yandex_vpc_security_group.web.ingress : rule if rule.port == 22]).v4_cidr_blocks) == toset([var.admin_cidr])
    )
    error_message = "Expose HTTP to clients and health probes; restrict SSH to the administrator CIDR."
  }

  assert {
    condition = (
      yandex_compute_instance_group.web.health_check[0].http_options[0].port == 80 &&
      yandex_compute_instance_group.web.health_check[0].http_options[0].path == "/health.php" &&
      yandex_lb_network_load_balancer.web.type == "external" &&
      one(yandex_lb_network_load_balancer.web.listener).protocol == "tcp" &&
      one(yandex_lb_network_load_balancer.web.listener).port == 80 &&
      one(yandex_lb_network_load_balancer.web.listener).target_port == 80 &&
      one(yandex_lb_network_load_balancer.web.attached_target_group).target_group_id == yandex_compute_instance_group.web.load_balancer[0].target_group_id &&
      one(yandex_lb_network_load_balancer.web.attached_target_group).healthcheck[0].http_options[0].port == 80 &&
      one(yandex_lb_network_load_balancer.web.attached_target_group).healthcheck[0].http_options[0].path == "/health.php"
    )
    error_message = "Both HTTP checks must hit /health.php on TCP/80, and the NLB must attach the IG-managed target group."
  }

  assert {
    condition = tomap({
      for entry in yamldecode(yandex_compute_instance_group.web.instance_template[0].metadata["user-data"]).write_files :
      entry.path => base64decode(entry.content) if entry.encoding == "b64"
      }) == tomap({
      "/var/www/html/index.php"  = replace(file("${path.module}/../app/index.php"), "__IMAGE_URL__", output.picture_url)
      "/var/www/html/health.php" = file("${path.module}/../app/health.php")
    })
    error_message = "The rendered cloud-init must install both PHP files and embed the anonymous object URL."
  }
}
