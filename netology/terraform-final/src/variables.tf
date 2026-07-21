variable "cloud_id" {
  type        = string
  description = "Yandex Cloud ID."
}

variable "folder_id" {
  type        = string
  description = "Yandex Cloud folder ID."
}

variable "service_account_key_file" {
  type        = string
  description = "Path to service account key json."
  sensitive   = true
}

variable "default_zone" {
  type        = string
  description = "Default zone for provider."
  default     = "ru-central1-a"
}

variable "ssh_public_key_path" {
  type        = string
  description = "Public SSH key for cloud-init user."
  default     = "~/.ssh/id_ed25519.pub"
}

variable "vm_service_account_id" {
  type        = string
  description = "Service account ID attached to VM for Container Registry pull."
  default     = ""
}

variable "app_name" {
  type        = string
  description = "Application name prefix."
  default     = "legacy-100-years"
}

variable "app_repo" {
  type        = string
  description = "Git repository with application sources."
  default     = "https://github.com/demon-5656/legacy-100-years.git"
}

variable "image_tag" {
  type        = string
  description = "Container image tag."
  default     = "latest"
}

variable "public_base_url" {
  type        = string
  description = "Application public URL. Can be changed to DNS name later."
  default     = ""
}

variable "subnets" {
  type = map(object({
    zone = string
    cidr = string
  }))

  description = "Subnets for application infrastructure."
  default = {
    app-a = {
      zone = "ru-central1-a"
      cidr = "10.30.1.0/24"
    }
    db-b = {
      zone = "ru-central1-b"
      cidr = "10.30.2.0/24"
    }
  }
}

variable "vm_platform_id" {
  type        = string
  description = "YC compute platform."
  default     = "standard-v1"
}

variable "vm_cores" {
  type        = number
  description = "VM CPU cores."
  default     = 2
}

variable "vm_memory" {
  type        = number
  description = "VM RAM in GB."
  default     = 2
}

variable "vm_core_fraction" {
  type        = number
  description = "VM core fraction for cheap homework stand."
  default     = 20
}

variable "vm_disk_size" {
  type        = number
  description = "VM boot disk size in GB."
  default     = 20
}

variable "mysql_password" {
  type        = string
  description = "MySQL app user password. For real work pass it through tfvars/env, not git."
  sensitive   = true
}

variable "mysql_database" {
  type        = string
  description = "Application database name."
  default     = "legacy_100_years"
}

variable "mysql_user" {
  type        = string
  description = "Application database user."
  default     = "legacy_app"
}

variable "jwt_secret" {
  type        = string
  description = "JWT signing secret for application."
  sensitive   = true
}

variable "smtp_host" {
  type        = string
  description = "SMTP server host."
  default     = ""
}

variable "smtp_port" {
  type        = number
  description = "SMTP server port."
  default     = 587
}

variable "smtp_secure" {
  type        = bool
  description = "Use SMTPS."
  default     = false
}

variable "smtp_user" {
  type        = string
  description = "SMTP username."
  default     = ""
}

variable "smtp_password" {
  type        = string
  description = "SMTP password."
  sensitive   = true
  default     = ""
}

variable "smtp_from" {
  type        = string
  description = "Mail from field."
  default     = "Legacy 100 Years <noreply@example.local>"
}
