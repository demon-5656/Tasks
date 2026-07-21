locals {
  ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))

  app_subnet = yandex_vpc_subnet.this["app-a"]
  db_subnet  = yandex_vpc_subnet.this["db-b"]

  registry_name = replace("${var.app_name}-registry", "_", "-")

  registry_url = "cr.yandex/${yandex_container_registry.app.id}"
  web_image    = "${local.registry_url}/${var.app_name}-web:${var.image_tag}"
  api_image    = "${local.registry_url}/${var.app_name}-api:${var.image_tag}"

  public_base_url = var.public_base_url != "" ? var.public_base_url : "http://${yandex_vpc_address.app.external_ipv4_address[0].address}"
}
