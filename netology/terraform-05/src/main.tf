locals {
  ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))

  vm_metadata = {
    user-data          = data.template_file.cloudinit.rendered
    serial-port-enable = "1"
  }

  validation_check = {
    single_ip      = var.single_ip
    ip_list        = var.ip_list
    lowercase_text = var.lowercase_text
    mac_leod       = var.in_the_end_there_can_be_only_one
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

resource "yandex_vpc_security_group" "vm" {
  name       = "netology-terraform-05-vm"
  network_id = module.vpc_dev.network_id

  ingress {
    protocol       = "TCP"
    description    = "ssh from develop network"
    port           = 22
    v4_cidr_blocks = ["10.10.0.0/16"]
  }

  ingress {
    protocol       = "TCP"
    description    = "http from develop network"
    port           = 80
    v4_cidr_blocks = ["10.10.0.0/16"]
  }

  egress {
    protocol       = "ANY"
    description    = "allow outbound traffic"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

module "marketing_vm" {
  source = "git::https://github.com/udjin10/yandex_compute_instance.git?ref=de7090ae115ee5059cd81053a808af079c325e01"

  env_name               = "marketing"
  network_id             = module.vpc_dev.network_id
  subnet_zones           = [var.dev_subnets[0].zone]
  subnet_ids             = [module.vpc_dev.subnet_ids[var.dev_subnets[0].zone]]
  instance_name          = "web"
  instance_count         = 1
  image_family           = var.image_family
  public_ip              = false
  security_group_ids     = [yandex_vpc_security_group.vm.id]
  platform               = var.vm_defaults.platform_id
  instance_cores         = var.vm_defaults.cores
  instance_memory        = var.vm_defaults.memory
  instance_core_fraction = var.vm_defaults.core_fraction
  boot_disk_size         = var.vm_defaults.boot_disk
  preemptible            = true

  labels = {
    project = "marketing"
    owner   = "netology"
    lesson  = "terraform-05"
  }

  metadata = local.vm_metadata
}

module "analytics_vm" {
  source = "git::https://github.com/udjin10/yandex_compute_instance.git?ref=de7090ae115ee5059cd81053a808af079c325e01"

  env_name               = "analytics"
  network_id             = module.vpc_dev.network_id
  subnet_zones           = [var.dev_subnets[1].zone]
  subnet_ids             = [module.vpc_dev.subnet_ids[var.dev_subnets[1].zone]]
  instance_name          = "web"
  instance_count         = 1
  image_family           = var.image_family
  public_ip              = false
  security_group_ids     = [yandex_vpc_security_group.vm.id]
  platform               = "standard-v3"
  instance_cores         = var.vm_defaults.cores
  instance_memory        = var.vm_defaults.memory
  instance_core_fraction = 20
  boot_disk_size         = var.vm_defaults.boot_disk
  preemptible            = true

  labels = {
    project = "analytics"
    owner   = "netology"
    lesson  = "terraform-05"
  }

  metadata = local.vm_metadata
}
