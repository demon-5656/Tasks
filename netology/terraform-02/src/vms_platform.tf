variable "vm_web_name" {
  type        = string
  default     = "platform-web"
  description = "Web VM short name"
}

variable "vm_web_image_family" {
  type        = string
  default     = "ubuntu-2004-lts"
  description = "OS image family"
}

variable "vm_web_platform_id" {
  type        = string
  default     = "standard-v1"
  description = "Web VM platform"
}

variable "vm_db_name" {
  type        = string
  default     = "platform-db"
  description = "DB VM short name"
}

variable "vm_db_platform_id" {
  type        = string
  default     = "standard-v3"
  description = "DB VM platform"
}

variable "vms_resources" {
  type = map(object({
    cores         = number
    memory        = number
    core_fraction = number
    hdd_size      = number
    hdd_type      = string
  }))

  default = {
    web = {
      cores         = 2
      memory        = 1
      core_fraction = 5
      hdd_size      = 10
      hdd_type      = "network-hdd"
    }
    db = {
      cores         = 2
      memory        = 2
      core_fraction = 20
      hdd_size      = 10
      hdd_type      = "network-hdd"
    }
  }

  description = "Resource settings for all VMs"
}

variable "metadata" {
  type = map(string)
  default = {
    serial-port-enable = "1"
  }
  description = "Common VM metadata"
}
