resource "yandex_mdb_mysql_cluster" "app" {
  name                = "${var.app_name}-mysql"
  environment         = "PRESTABLE"
  network_id          = yandex_vpc_network.app.id
  version             = "8.0"
  security_group_ids  = [yandex_vpc_security_group.mysql.id]
  deletion_protection = false

  resources {
    resource_preset_id = "s2.micro"
    disk_type_id       = "network-hdd"
    disk_size          = 10
  }

  host {
    zone      = local.db_subnet.zone
    subnet_id = local.db_subnet.id
  }
}

resource "yandex_mdb_mysql_database" "app" {
  cluster_id = yandex_mdb_mysql_cluster.app.id
  name       = var.mysql_database
}

resource "yandex_mdb_mysql_user" "app" {
  cluster_id = yandex_mdb_mysql_cluster.app.id
  name       = var.mysql_user
  password   = var.mysql_password

  permission {
    database_name = yandex_mdb_mysql_database.app.name
    roles         = ["ALL"]
  }
}
