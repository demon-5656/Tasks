output "marketing_vm" {
  value = {
    external_ip = module.marketing_vm.external_ip_address
    fqdn        = module.marketing_vm.fqdn
    labels      = module.marketing_vm.labels
  }
}

output "analytics_vm" {
  value = {
    external_ip = module.analytics_vm.external_ip_address
    fqdn        = module.analytics_vm.fqdn
    labels      = module.analytics_vm.labels
  }
}

output "vpc_dev" {
  value = module.vpc_dev
}

output "validation_check" {
  value = local.validation_check
}
