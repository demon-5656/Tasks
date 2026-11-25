output "nat_internal_ip" {
  description = "Внутренний адрес NAT-инстанса (next hop)."
  value       = yandex_compute_instance.nat.network_interface[0].ip_address
}

output "nat_public_ip" {
  description = "Внешний IPv4-адрес NAT-инстанса."
  value       = yandex_compute_instance.nat.network_interface[0].nat_ip_address
}

output "public_vm_ip" {
  description = "Внешний IPv4-адрес public VM."
  value       = yandex_compute_instance.app["public"].network_interface[0].nat_ip_address
}

output "private_vm_ip" {
  description = "Внутренний IPv4-адрес private VM."
  value       = yandex_compute_instance.app["private"].network_interface[0].ip_address
}

output "ssh_private_via_public" {
  description = "Команда подключения с машины администратора без копирования приватного ключа на public VM."
  value       = "ssh -J ${var.ssh_user}@${yandex_compute_instance.app["public"].network_interface[0].nat_ip_address} ${var.ssh_user}@${yandex_compute_instance.app["private"].network_interface[0].ip_address}"
}
