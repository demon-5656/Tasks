terraform {
  required_version = "~> 1.13.5"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.250.0"
    }
  }
}

provider "yandex" {
  folder_id = var.folder_id
}
