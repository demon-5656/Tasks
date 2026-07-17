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
  description = "Default provider zone"
}

variable "ssh_public_key_path" {
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
  description = "Public SSH key for cloud-init"
}

variable "image_family" {
  type        = string
  default     = "ubuntu-2004-lts"
  description = "VM image family"
}

variable "vm_defaults" {
  type = object({
    platform_id   = string
    cores         = number
    memory        = number
    core_fraction = number
    boot_disk     = number
  })

  default = {
    platform_id   = "standard-v1"
    cores         = 2
    memory        = 1
    core_fraction = 5
    boot_disk     = 10
  }
}

variable "dev_subnets" {
  type = list(object({
    zone = string
    cidr = string
  }))

  default = [
    {
      zone = "ru-central1-a"
      cidr = "10.10.1.0/24"
    },
    {
      zone = "ru-central1-b"
      cidr = "10.10.2.0/24"
    }
  ]
}

variable "prod_example_subnets" {
  type = list(object({
    zone = string
    cidr = string
  }))

  default = [
    {
      zone = "ru-central1-a"
      cidr = "10.20.1.0/24"
    },
    {
      zone = "ru-central1-b"
      cidr = "10.20.2.0/24"
    },
    {
      zone = "ru-central1-d"
      cidr = "10.20.4.0/24"
    }
  ]
}
