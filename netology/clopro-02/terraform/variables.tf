variable "folder_id" {
  type        = string
  description = "Folder ID for new resources; supply the provider credentials outside Terraform files."
}

variable "public_subnet_id" {
  type        = string
  description = "ID of the existing public subnet from 15.1. Replace the example; no VPC or subnet will be created."
  default     = "e9b-replace-with-public-subnet-id"
}

variable "bucket_name" {
  type        = string
  description = "Globally unique Object Storage bucket name (3–63 lowercase letters, digits and hyphens)."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Use 3–63 lowercase letters, digits or hyphens, beginning and ending with a letter or digit."
  }
}

variable "lamp_image_id" {
  type        = string
  description = "LAMP boot image ID recommended in assignment 15.2. Override explicitly if it is unavailable."
  default     = "fd827b91d99psvq5fjit"
}

variable "admin_cidr" {
  type        = string
  description = "Administrator's IPv4 CIDR for inbound SSH (prefer a single public IP with /32)."

  validation {
    condition     = try(cidrnetmask(var.admin_cidr) != "0.0.0.0", false)
    error_message = "Supply a specific IPv4 CIDR, not an unrestricted /0."
  }
}

variable "ssh_public_key" {
  type        = string
  description = "OpenSSH public key for webadmin. Never supply a private key."

  validation {
    condition     = can(regex("^(ssh-(ed25519|rsa)|ecdsa-sha2-nistp(256|384|521)) [A-Za-z0-9+/]+={0,2}([ \t][^\r\n]*)?$", trimspace(var.ssh_public_key)))
    error_message = "Supply a single OpenSSH public key line, not a private key."
  }
}
