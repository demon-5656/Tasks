resource "yandex_lockbox_secret" "app" {
  name = "${var.app_name}-secrets"
}

resource "yandex_lockbox_secret_version" "app" {
  secret_id = yandex_lockbox_secret.app.id

  entries {
    key        = "mysql_password"
    text_value = var.mysql_password
  }

  entries {
    key        = "jwt_secret"
    text_value = var.jwt_secret
  }

  entries {
    key        = "smtp_password"
    text_value = var.smtp_password
  }
}
