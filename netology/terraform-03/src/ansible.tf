resource "local_file" "ansible_inventory" {
  filename = "${path.module}/hosts.cfg"
  content = templatefile("${path.module}/templates/hosts.tftpl", {
    webservers = local.web_inventory
    databases  = local.database_inventory
    storage    = local.storage_inventory
  })
}
