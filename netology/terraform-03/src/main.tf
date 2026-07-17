resource "yandex_vpc_network" "develop" {
  name = var.vpc_name
}

resource "yandex_vpc_subnet" "main" {
  name           = "${var.vpc_name}-${var.default_zone}"
  zone           = var.default_zone
  network_id     = yandex_vpc_network.develop.id
  v4_cidr_blocks = var.default_cidr
}

resource "yandex_vpc_subnet" "db" {
  name           = "${var.vpc_name}-${var.db_zone}"
  zone           = var.db_zone
  network_id     = yandex_vpc_network.develop.id
  v4_cidr_blocks = var.db_cidr
}

data "yandex_compute_image" "ubuntu" {
  family = var.ubuntu_image_family
}
