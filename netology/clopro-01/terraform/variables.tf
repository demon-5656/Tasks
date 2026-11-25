variable "cloud_id" {
  description = "Идентификатор облака Yandex Cloud."
  type        = string
}

variable "folder_id" {
  description = "Идентификатор каталога Yandex Cloud."
  type        = string
}

variable "zone" {
  description = "Зона доступности для обеих подсетей и всех ВМ."
  type        = string
  default     = "ru-central1-a"
}

variable "admin_cidr" {
  description = "Доверенный IPv4 CIDR для SSH к public VM, обычно внешний IP администратора с маской /32."
  type        = string

  validation {
    condition     = try(cidrnetmask(var.admin_cidr) != "0.0.0.0", false)
    error_message = "Укажите доверенный IPv4 CIDR с маской от /1 до /32, не открытую всему интернету сеть /0."
  }
}

variable "ssh_user" {
  description = "Локальный непривилегированный пользователь, создаваемый cloud-init на public и private VM."
  type        = string
  default     = "labadmin"

  validation {
    condition     = can(regex("^[a-z_][a-z0-9_-]{0,31}$", var.ssh_user)) && var.ssh_user != "root"
    error_message = "Укажите допустимое имя пользователя Linux, отличное от root."
  }
}

variable "ssh_public_key" {
  description = "Содержимое публичного SSH-ключа в формате OpenSSH; не передавайте приватный ключ."
  type        = string

  validation {
    condition     = can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521)) [A-Za-z0-9+/]+={0,2}( [^\r\n]*)?$", trimspace(var.ssh_public_key)))
    error_message = "Укажите одну строку с публичным SSH-ключом в формате OpenSSH."
  }
}
