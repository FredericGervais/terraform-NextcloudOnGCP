#
# Dependance:
#  google_container_node_pool.primary_nodes
#  null_resource.export-custom-routes
#

resource "null_resource" "configure_kubectl" {
  depends_on = [
    google_container_node_pool.primary_nodes,
    google_sql_database_instance.master,
    google_filestore_instance.instance,
    null_resource.export-custom-routes
  ]

  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${google_container_cluster.primary.location} --project ${google_container_cluster.primary.project}"
  }
}

provider "kubernetes" {
}

resource "kubernetes_secret" "database-credentials" {
  depends_on = [null_resource.configure_kubectl]

  metadata {
    name = "database-credentials-${random_id.cluster_name_suffix.hex}"
  }

  data = {
    MYSQL_USER = google_sql_user.users.name
    MYSQL_PASSWORD = google_sql_user.users.password
  }
}

resource "kubernetes_deployment" "application" {
  depends_on = [kubernetes_secret.database-credentials]

  metadata {
    name = "${var.app-name}-deployment"
    labels = {
      app = var.app-name
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = var.app-name
      }
    }

    template {
      metadata {
        labels = {
          app = var.app-name
        }
      }

      spec {
        container {
          image = "nextcloud:latest"
          name  = var.app-name
          port {
            container_port = 8080
          }
          volume_mount {
            name       = "nfs-volume"
            mount_path = "/var/www/html"
          }
          env {
            name  = "MYSQL_HOST"
            value = google_sql_database_instance.master.private_ip_address
          }
          env {
            name  = "MYSQL_DATABASE"
            value = google_sql_database.database.name
          }
          env {
            name = "MYSQL_USER"
            value_from {
              secret_key_ref {
                name = "database-credentials-${random_id.cluster_name_suffix.hex}"
                key  = "MYSQL_USER"
              }
            }
          }
          env {
            name = "MYSQL_PASSWORD"
            value_from {
              secret_key_ref {
                name = "database-credentials-${random_id.cluster_name_suffix.hex}"
                key  = "MYSQL_PASSWORD"
              }
            }
          }
          resources {
            limits {
              cpu    = "2"
              memory = "512Mi"
            }
            requests {
              cpu    = "250m"
              memory = "256Mi"
            }
          }
        }
        volume {
          name = "nfs-volume"
          nfs {
            path   = "/${google_filestore_instance.instance.file_shares[0].name}"
            server = google_filestore_instance.instance.networks[0].ip_addresses[0]
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "expose" {
  depends_on = [null_resource.configure_kubectl]

  metadata {
    name = "expose-${var.app-name}-${random_id.cluster_name_suffix.hex}"
  }
  spec {
    selector = {
      app = var.app-name
    }
    session_affinity = "ClientIP"
    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}

