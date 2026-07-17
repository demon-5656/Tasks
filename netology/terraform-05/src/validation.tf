variable "single_ip" {
  type        = string
  description = "ip-address"
  default     = "192.168.0.1"

  validation {
    condition     = can(cidrhost("${var.single_ip}/32", 0))
    error_message = "single_ip must be a valid IPv4 address."
  }
}

variable "ip_list" {
  type        = list(string)
  description = "list of ip-addresses"
  default     = ["192.168.0.1", "1.1.1.1", "127.0.0.1"]

  validation {
    condition = alltrue([
      for ip in var.ip_list : can(cidrhost("${ip}/32", 0))
    ])
    error_message = "Every item in ip_list must be a valid IPv4 address."
  }
}

variable "lowercase_text" {
  type        = string
  description = "any lowercase string"
  default     = "terraform team work"

  validation {
    condition     = var.lowercase_text == lower(var.lowercase_text)
    error_message = "lowercase_text must not contain uppercase symbols."
  }
}

variable "in_the_end_there_can_be_only_one" {
  description = "Who is better Connor or Duncan?"
  type = object({
    Dunkan = optional(bool, false)
    Connor = optional(bool, false)
  })

  default = {
    Dunkan = true
    Connor = false
  }

  validation {
    condition     = var.in_the_end_there_can_be_only_one.Dunkan != var.in_the_end_there_can_be_only_one.Connor
    error_message = "There can be only one MacLeod."
  }
}
