#
# Dependance:
#  google_service_networking_connection.private_vpc_connection
#  var.region
#

resource "google_project_service" "kubernetes" {
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

resource "google_container_cluster" "primary" {
  provider = google-beta

  name     = "terraform-${var.app-name}-${random_id.cluster_name_suffix.hex}"
  location = var.region
  depends_on = [
    google_compute_network.private_network,
    google_project_service.kubernetes,
  ]
  network = google_compute_network.private_network.self_link

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  cluster_autoscaling {
    enabled = true
    resource_limits {
      resource_type = "cpu"
      maximum       = 64
      minimum       = 1
    }
    resource_limits {
      resource_type = "memory"
      maximum       = 96
      minimum       = 1
    }
  }

  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }
}

resource "google_container_node_pool" "primary_nodes" {
  name     = "node-pool"
  location = var.region
  cluster  = google_container_cluster.primary.name

  # This makes sure the node count reaches at least 1 before flagging this resource as ready
  # It is necessary or else deploying a Pod right after would end with an error linked to the Pod not being schedulable
  initial_node_count = 1

  node_config {
    machine_type = "n1-standard-4"

    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
}

