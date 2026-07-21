output "app_url" {
  value       = local.public_base_url
  description = "Application URL."
}

output "app_public_ip" {
  value       = yandex_vpc_address.app.external_ipv4_address[0].address
  description = "Application VM public IP."
}

output "registry_url" {
  value       = local.registry_url
  description = "Yandex Container Registry URL."
}

output "web_image" {
  value       = local.web_image
  description = "Web container image."
}

output "api_image" {
  value       = local.api_image
  description = "API container image."
}

output "mysql_host" {
  value       = yandex_mdb_mysql_cluster.app.host[0].fqdn
  description = "Managed MySQL host."
}

output "lockbox_secret_id" {
  value       = yandex_lockbox_secret.app.id
  description = "Lockbox secret with app secrets."
}
