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

output "NFS_share_path" {
  value       = "${google_filestore_instance.instance.networks[0].ip_addresses[0]}/${google_filestore_instance.instance.file_shares[0].name}"
  description = "The path to the NFS share"
  sensitive   = false
}