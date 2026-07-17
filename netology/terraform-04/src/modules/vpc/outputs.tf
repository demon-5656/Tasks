output "network_id" {
  description = "Created network ID"
  value       = yandex_vpc_network.this.id
}

output "network_name" {
  description = "Created network name"
  value       = yandex_vpc_network.this.name
}

output "subnets" {
  description = "Created subnets"
  value       = yandex_vpc_subnet.this
}

output "subnet_ids" {
  description = "Subnet IDs by zone"
  value = {
    for subnet in var.subnets : subnet.zone => try(yandex_vpc_subnet.this[subnet.zone].id, null)
  }
}

output "subnet_info" {
  description = "Short subnet info by zone"
  value = {
    for subnet in var.subnets : subnet.zone => {
      id   = try(yandex_vpc_subnet.this[subnet.zone].id, null)
      name = try(yandex_vpc_subnet.this[subnet.zone].name, "${var.env_name}-${subnet.zone}")
      zone = subnet.zone
      cidr = try(yandex_vpc_subnet.this[subnet.zone].v4_cidr_blocks, [subnet.cidr])
    }
  }
}
