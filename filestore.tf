#
# Dependance:
#  google_compute_network.private_network
#

resource "google_filestore_instance" "instance" {
  name = "nfsshare-${random_id.db_name_suffix.hex}"
  tier = "STANDARD"
  zone = "us-east1-b"

  file_shares {
    capacity_gb = 2048
    name        = "NFSvol"
  }

  networks {
    network = google_compute_network.private_network.name
    modes   = ["MODE_IPV4"]
  }
}

