locals {
  public_cidr  = "192.168.10.0/24"
  private_cidr = "192.168.20.0/24"

  app_network = {
    public = {
      subnet_id         = yandex_vpc_subnet.public.id
      public_ip         = true
      security_group_id = yandex_vpc_security_group.public.id
    }
    private = {
      subnet_id         = yandex_vpc_subnet.private.id
      public_ip         = false
      security_group_id = yandex_vpc_security_group.private.id
    }
  }
}

data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

resource "yandex_vpc_network" "lab" {
  name = "clopro-15-1"
}

resource "yandex_vpc_subnet" "public" {
  name           = "public"
  zone           = var.zone
  network_id     = yandex_vpc_network.lab.id
  v4_cidr_blocks = [local.public_cidr]
}

resource "yandex_vpc_subnet" "private" {
  name           = "private"
  zone           = var.zone
  network_id     = yandex_vpc_network.lab.id
  route_table_id = yandex_vpc_route_table.private.id
  v4_cidr_blocks = [local.private_cidr]
}

resource "yandex_vpc_route_table" "private" {
  name       = "private-via-nat"
  network_id = yandex_vpc_network.lab.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    next_hop_address   = yandex_compute_instance.nat.network_interface[0].ip_address
  }
}

resource "yandex_vpc_security_group" "public" {
  name       = "clopro-public"
  network_id = yandex_vpc_network.lab.id

  ingress {
    description    = "SSH from the administrator"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = [var.admin_cidr]
  }

  egress {
    description    = "IPv4 internet and SSH to private VM"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "private" {
  name       = "clopro-private"
  network_id = yandex_vpc_network.lab.id

  ingress {
    description       = "SSH only from the public VM security group"
    protocol          = "TCP"
    port              = 22
    security_group_id = yandex_vpc_security_group.public.id
  }

  egress {
    description    = "IPv4 destinations routed via NAT when outside the VPC"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "nat" {
  name       = "clopro-nat"
  network_id = yandex_vpc_network.lab.id

  ingress {
    description    = "Forwarded traffic from the private subnet; no internet ingress"
    protocol       = "ANY"
    v4_cidr_blocks = [local.private_cidr]
  }

  egress {
    description    = "Forward traffic to IPv4 internet"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_compute_instance" "nat" {
  name        = "nat-instance"
  zone        = var.zone
  platform_id = "standard-v3"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd80mrhj8fl2oe87o4e1"
      size     = 20
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public.id
    ip_address         = "192.168.10.254"
    nat                = true
    security_group_ids = [yandex_vpc_security_group.nat.id]
  }
}

resource "yandex_compute_instance" "app" {
  for_each = local.app_network

  name        = "${each.key}-vm"
  zone        = var.zone
  platform_id = "standard-v3"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 20
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = each.value.subnet_id
    nat                = each.value.public_ip
    security_group_ids = [each.value.security_group_id]
  }

  metadata = {
    user-data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
      ssh_user       = var.ssh_user
      ssh_public_key = trimspace(var.ssh_public_key)
    })
  }
}
