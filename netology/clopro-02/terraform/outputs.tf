output "picture_url" {
  description = "Anonymous HTTPS URL of the picture in Object Storage."
  value       = local.picture_url
}

locals {
  nlb_address = one(flatten([
    for listener in yandex_lb_network_load_balancer.web.listener : [
      for external in listener.external_address_spec : external.address
    ]
  ]))
}

output "nlb_http_url" {
  description = "HTTP entry point of the external Network Load Balancer, once its address is allocated."
  value       = local.nlb_address == null ? null : "http://${local.nlb_address}/"
}

output "instance_group_id" {
  description = "ID of the three-instance LAMP group."
  value       = yandex_compute_instance_group.web.id
}
