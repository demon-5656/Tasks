variable "cloud_id" {
  type        = string
  description = "Yandex Cloud ID"
}

variable "folder_id" {
  type        = string
  description = "Yandex Cloud folder ID"
}

variable "service_account_key_file" {
  type        = string
  description = "Path to service account key json"
  sensitive   = true
}

variable "default_zone" {
  type        = string
  default     = "ru-central1-a"
  description = "Main zone"
}

variable "db_zone" {
  type        = string
  default     = "ru-central1-b"
  description = "Zone for database nodes"
}

variable "default_cidr" {
  type        = list(string)
  default     = ["10.0.1.0/24"]
  description = "Main subnet CIDR"
}

variable "db_cidr" {
  type        = list(string)
  default     = ["10.0.2.0/24"]
  description = "Database subnet CIDR"
}

variable "vpc_name" {
  type        = string
  default     = "develop"
  description = "VPC network name"
}

variable "ssh_public_key_path" {
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
  description = "Local public SSH key path"
}

variable "ubuntu_image_family" {
  type        = string
  default     = "ubuntu-2004-lts"
  description = "Base image family"
}

variable "web_count" {
  type        = number
  default     = 2
  description = "Web VM count"
}

variable "web_resources" {
  type = object({
    platform_id   = string
    cores         = number
    memory        = number
    core_fraction = number
    disk_size     = number
    disk_type     = string
  })

  default = {
    platform_id   = "standard-v1"
    cores         = 2
    memory        = 1
    core_fraction = 5
    disk_size     = 10
    disk_type     = "network-hdd"
  }
}

variable "each_vm" {
  type = list(object({
    vm_name     = string
    cpu         = number
    ram         = number
    disk_volume = number
    platform_id = string
    fraction    = number
  }))

  default = [
    {
      vm_name     = "main"
      cpu         = 2
      ram         = 2
      disk_volume = 10
      platform_id = "standard-v3"
      fraction    = 20
    },
    {
      vm_name     = "replica"
      cpu         = 2
      ram         = 2
      disk_volume = 12
      platform_id = "standard-v3"
      fraction    = 20
    }
  ]
}

variable "storage_resources" {
  type = object({
    platform_id   = string
    cores         = number
    memory        = number
    core_fraction = number
    boot_disk     = number
    extra_disks   = number
  })

  default = {
    platform_id   = "standard-v1"
    cores         = 2
    memory        = 1
    core_fraction = 5
    boot_disk     = 10
    extra_disks   = 3
  }
}
