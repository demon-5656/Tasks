mock_provider "yandex" {
  mock_data "yandex_compute_image" {
    defaults = {
      id = "mock-ubuntu-image"
    }
  }
}

variables {
  cloud_id       = "mock-cloud"
  folder_id      = "mock-folder"
  admin_cidr     = "203.0.113.10/32"
  ssh_user       = "testuser"
  ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA fixture-only"
}

run "network_topology" {
  # Mock apply resolves resource IDs needed to assert network bindings.
  command = apply

  providers = {
    yandex = yandex
  }

  assert {
    condition = (
      yandex_vpc_subnet.public.name == "public" &&
      yandex_vpc_subnet.private.name == "private" &&
      toset(yandex_vpc_subnet.public.v4_cidr_blocks) == toset(["192.168.10.0/24"]) &&
      toset(yandex_vpc_subnet.private.v4_cidr_blocks) == toset(["192.168.20.0/24"]) &&
      yandex_vpc_subnet.public.network_id == yandex_vpc_network.lab.id &&
      yandex_vpc_subnet.private.network_id == yandex_vpc_network.lab.id
    )
    error_message = "В одной VPC ожидаются public 192.168.10.0/24 и private 192.168.20.0/24."
  }

  assert {
    condition = (
      length(yandex_compute_instance.app) + length([yandex_compute_instance.nat]) == 3 &&
      toset(keys(yandex_compute_instance.app)) == toset(["public", "private"])
    )
    error_message = "Ожидаются три VM: NAT, public и private."
  }

  assert {
    condition = (
      yandex_compute_instance.nat.boot_disk[0].initialize_params[0].image_id == "fd80mrhj8fl2oe87o4e1" &&
      one(yandex_compute_instance.nat.network_interface).subnet_id == yandex_vpc_subnet.public.id &&
      one(yandex_compute_instance.nat.network_interface).ip_address == "192.168.10.254" &&
      one(yandex_compute_instance.nat.network_interface).nat
    )
    error_message = "NAT должен использовать точный image_id из задания и адрес 192.168.10.254 в public с публичным IP."
  }

  assert {
    condition = (
      one(yandex_compute_instance.app["public"].network_interface).subnet_id == yandex_vpc_subnet.public.id &&
      one(yandex_compute_instance.app["public"].network_interface).nat &&
      one(yandex_compute_instance.app["private"].network_interface).subnet_id == yandex_vpc_subnet.private.id &&
      !one(yandex_compute_instance.app["private"].network_interface).nat
    )
    error_message = "Public VM нужна своя подсеть и публичный IP; private VM — своя подсеть и nat = false."
  }

  assert {
    condition = (
      yandex_vpc_subnet.private.route_table_id == yandex_vpc_route_table.private.id &&
      yandex_vpc_subnet.public.route_table_id == null &&
      yandex_vpc_route_table.private.network_id == yandex_vpc_network.lab.id &&
      one(yandex_vpc_route_table.private.static_route).destination_prefix == "0.0.0.0/0" &&
      one(yandex_vpc_route_table.private.static_route).next_hop_address == "192.168.10.254"
    )
    error_message = "Только private должна использовать таблицу с единственным маршрутом 0.0.0.0/0 через 192.168.10.254."
  }

  assert {
    condition = (
      one(yandex_compute_instance.app["public"].network_interface).security_group_ids == toset([yandex_vpc_security_group.public.id]) &&
      one(yandex_compute_instance.app["private"].network_interface).security_group_ids == toset([yandex_vpc_security_group.private.id]) &&
      one(yandex_vpc_security_group.public.ingress).protocol == "TCP" &&
      one(yandex_vpc_security_group.public.ingress).port == 22 &&
      toset(one(yandex_vpc_security_group.public.ingress).v4_cidr_blocks) == toset([var.admin_cidr]) &&
      one(yandex_vpc_security_group.private.ingress).protocol == "TCP" &&
      one(yandex_vpc_security_group.private.ingress).port == 22 &&
      one(yandex_vpc_security_group.private.ingress).security_group_id == yandex_vpc_security_group.public.id &&
      length(coalesce(one(yandex_vpc_security_group.private.ingress).v4_cidr_blocks, [])) == 0
    )
    error_message = "Входящий SSH разрешён только admin_cidr → public и только public SG → private."
  }

  assert {
    condition = (
      one(yandex_compute_instance.nat.network_interface).security_group_ids == toset([yandex_vpc_security_group.nat.id]) &&
      one(yandex_vpc_security_group.nat.ingress).protocol == "ANY" &&
      toset(one(yandex_vpc_security_group.nat.ingress).v4_cidr_blocks) == toset(["192.168.20.0/24"]) &&
      alltrue([for sg in [yandex_vpc_security_group.public, yandex_vpc_security_group.private, yandex_vpc_security_group.nat] :
        one(sg.egress).protocol == "ANY" && toset(one(sg.egress).v4_cidr_blocks) == toset(["0.0.0.0/0"])
      ])
    )
    error_message = "NAT принимает транзит из private CIDR, все три группы разрешают исходящий IPv4-трафик."
  }

  assert {
    condition = (
      data.yandex_compute_image.ubuntu.family == "ubuntu-2204-lts" &&
      alltrue([for vm in yandex_compute_instance.app :
        vm.boot_disk[0].initialize_params[0].image_id == "mock-ubuntu-image" &&
        !yamldecode(vm.metadata["user-data"]).ssh_pwauth &&
        one(yamldecode(vm.metadata["user-data"]).users).name == var.ssh_user &&
        one(one(yamldecode(vm.metadata["user-data"]).users).ssh_authorized_keys) == var.ssh_public_key
      ])
    )
    error_message = "Обе app VM используют Ubuntu 22.04 LTS и получают пользователя и публичный ключ через cloud-init."
  }
}
