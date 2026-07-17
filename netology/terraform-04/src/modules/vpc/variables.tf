variable "env_name" {
  type        = string
  description = "Environment/network name"
}

variable "subnets" {
  type = list(object({
    zone = string
    cidr = string
  }))
  description = "Subnets to create"
}
