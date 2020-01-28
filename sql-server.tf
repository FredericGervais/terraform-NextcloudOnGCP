#
# Dependance:
#  google_service_networking_connection.private_vpc_connection
#  var.region
#

resource "google_project_service" "sql" {
  service            = "sqladmin.googleapis.com"
  disable_on_destroy = false
}

resource "google_sql_database_instance" "master" {
  provider = google-beta

  name             = "${var.app-name}-database-${random_id.db_name_suffix.hex}"
  database_version = "MYSQL_5_7"
  region           = var.region
  depends_on       = [google_service_networking_connection.private_vpc_connection, google_project_service.sql]

  settings {
    # Second-generation instance tiers are based on the machine
    # type. See argument reference below.
    tier              = "db-n1-standard-4"
    availability_type = "REGIONAL"
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.private_network.self_link
    }
    backup_configuration {
      enabled            = true
      binary_log_enabled = true
    }
  }
}

resource "google_sql_database" "database" {
  name      = var.app-name
  instance  = google_sql_database_instance.master.name
  charset   = "utf8"
  collation = "utf8_general_ci"
}

resource "google_sql_user" "users" {
  name     = "root"
  instance = google_sql_database_instance.master.name
  password = random_id.db_user_password.b64_url
}

