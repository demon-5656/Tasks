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
  description = "Default zone for web VM"
}

variable "default_cidr" {
  type        = list(string)
  default     = ["10.0.1.0/24"]
  description = "CIDR for web subnet"
}

variable "vm_db_zone" {
  type        = string
  default     = "ru-central1-b"
  description = "Zone for db VM"
}

variable "vm_db_cidr" {
  type        = list(string)
  default     = ["10.0.2.0/24"]
  description = "CIDR for db subnet"
}

variable "vpc_name" {
  type        = string
  default     = "develop"
  description = "VPC network name"
}

variable "project_name" {
  type        = string
  default     = "netology"
  description = "Prefix for VM names"
}

variable "env_name" {
  type        = string
  default     = "develop"
  description = "Environment name"
}

variable "vms_ssh_public_root_key" {
  type        = string
  description = "Public SSH key for ubuntu user"
}
