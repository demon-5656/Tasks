locals {
  ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))

  vm_metadata = {
    user-data          = data.template_file.cloudinit.rendered
    serial-port-enable = "1"
  }
}

data "template_file" "cloudinit" {
  template = file("${path.module}/templates/cloud-init.yml")

  vars = {
    ssh_public_key = local.ssh_public_key
  }
}

module "vpc_dev" {
  source   = "./modules/vpc"
  env_name = "develop"
  subnets  = var.dev_subnets
}

module "marketing_vm" {
  source = "git::https://github.com/udjin10/yandex_compute_instance.git?ref=main"

  env_name               = "marketing"
  network_id             = module.vpc_dev.network_id
  subnet_zones           = [var.dev_subnets[0].zone]
  subnet_ids             = [module.vpc_dev.subnet_ids[var.dev_subnets[0].zone]]
  instance_name          = "web"
  instance_count         = 1
  image_family           = var.image_family
  public_ip              = true
  platform               = var.vm_defaults.platform_id
  instance_cores         = var.vm_defaults.cores
  instance_memory        = var.vm_defaults.memory
  instance_core_fraction = var.vm_defaults.core_fraction
  boot_disk_size         = var.vm_defaults.boot_disk
  preemptible            = true

  labels = {
    project = "marketing"
    owner   = "netology"
    lesson  = "terraform-04"
  }

  metadata = local.vm_metadata
}

module "analytics_vm" {
  source = "git::https://github.com/udjin10/yandex_compute_instance.git?ref=main"

  env_name               = "analytics"
  network_id             = module.vpc_dev.network_id
  subnet_zones           = [var.dev_subnets[1].zone]
  subnet_ids             = [module.vpc_dev.subnet_ids[var.dev_subnets[1].zone]]
  instance_name          = "web"
  instance_count         = 1
  image_family           = var.image_family
  public_ip              = true
  platform               = "standard-v3"
  instance_cores         = var.vm_defaults.cores
  instance_memory        = var.vm_defaults.memory
  instance_core_fraction = 20
  boot_disk_size         = var.vm_defaults.boot_disk
  preemptible            = true

  labels = {
    project = "analytics"
    owner   = "netology"
    lesson  = "terraform-04"
  }

  metadata = local.vm_metadata
}
