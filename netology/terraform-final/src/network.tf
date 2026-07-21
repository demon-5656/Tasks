resource "yandex_vpc_network" "app" {
  name = "${var.app_name}-vpc"
}

resource "yandex_vpc_subnet" "this" {
  for_each = var.subnets

  name           = "${var.app_name}-${each.key}"
  zone           = each.value.zone
  network_id     = yandex_vpc_network.app.id
  v4_cidr_blocks = [each.value.cidr]
}

resource "yandex_vpc_security_group" "app" {
  name       = "${var.app_name}-app-sg"
  network_id = yandex_vpc_network.app.id

  ingress {
    protocol       = "TCP"
    description    = "SSH"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "HTTP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "HTTPS"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    description    = "Outbound traffic"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "mysql" {
  name       = "${var.app_name}-mysql-sg"
  network_id = yandex_vpc_network.app.id

  ingress {
    protocol          = "TCP"
    description       = "MySQL from app VM"
    port              = 3306
    security_group_id = yandex_vpc_security_group.app.id
  }

  egress {
    protocol       = "ANY"
    description    = "Outbound traffic"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}
