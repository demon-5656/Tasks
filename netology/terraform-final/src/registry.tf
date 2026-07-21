resource "yandex_container_registry" "app" {
  name = local.registry_name
}
