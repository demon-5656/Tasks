terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 4.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }

  required_version = ">= 1.12.0"
}

provider "docker" {
  host = var.docker_host
}

resource "random_password" "mysql_root" {
  length  = 20
  special = false
}

resource "random_password" "mysql_user" {
  length  = 20
  special = false
}

resource "docker_image" "mysql" {
  name         = "mysql:8"
  keep_locally = true
}

resource "docker_container" "mysql" {
  image = docker_image.mysql.image_id
  name  = "tf-mysql-wordpress"

  env = [
    "MYSQL_ROOT_PASSWORD=${random_password.mysql_root.result}",
    "MYSQL_DATABASE=wordpress",
    "MYSQL_USER=wordpress",
    "MYSQL_PASSWORD=${random_password.mysql_user.result}",
    "MYSQL_ROOT_HOST=%",
  ]

  ports {
    ip       = "127.0.0.1"
    internal = 3306
    external = 3306
  }
}

output "container_name" {
  value = docker_container.mysql.name
}

output "mysql_user" {
  value = "wordpress"
}

output "mysql_password" {
  value     = random_password.mysql_user.result
  sensitive = true
}
