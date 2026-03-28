resource "tls_private_key" "node" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

data "google_compute_network" "lan" {
  name = var.network.lan.name
}

data "google_compute_subnetwork" "lan" {
  name   = "${var.network.lan.name}-subnet"
  region = var.location
}

resource "google_compute_firewall" "internal" {
  count = var.purpose == "master" ? 1 : 0

  description = "rock8s ${var.cluster_name}: allow full east-west traffic on the LAN subnet"
  name        = "${local.cluster}-internal"
  network     = data.google_compute_network.lan.name

  source_ranges = [var.network.lan.ipv4.subnet]
  target_tags   = local.node_tags

  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
}

resource "google_compute_firewall" "ssh_public" {
  count = var.purpose == "master" && !local.has_gateway ? 1 : 0

  description = "rock8s ${var.cluster_name}: SSH from public (WAN-only mode)"
  name        = "${local.cluster}-ssh-public"
  network     = data.google_compute_network.lan.name

  source_ranges = ["0.0.0.0/0"]
  target_tags   = local.node_tags

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "egress" {
  count = var.purpose == "master" ? 1 : 0

  description        = "rock8s ${var.cluster_name}: explicit allow-all egress for tagged nodes"
  name               = "${local.cluster}-egress-allow"
  network            = data.google_compute_network.lan.name
  direction          = "EGRESS"
  priority           = 65534
  target_tags        = local.node_tags
  destination_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "all"
  }
}

resource "google_compute_instance" "nodes" {
  count = length(local.node_configs)

  name         = local.node_configs[count.index].name
  machine_type = local.node_configs[count.index].machine_type
  zone         = local.zone

  deletion_protection = true

  tags = local.node_tags

  labels = {
    cluster = var.cluster_name
    purpose = var.purpose
  }

  boot_disk {
    initialize_params {
      image = local.node_configs[count.index].boot_image
      size  = 20
      type  = "pd-balanced"
    }
  }

  network_interface {
    network    = data.google_compute_network.lan.id
    subnetwork = data.google_compute_subnetwork.lan.id
    network_ip = local.node_configs[count.index].network_ip

    access_config {
      network_tier = "PREMIUM"
    }
  }

  metadata = {
    ssh-keys  = "admin:${chomp(tls_private_key.node.public_key_openssh)}"
    user-data = local.cloud_init
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  lifecycle {
    ignore_changes = [
      metadata["user-data"],
      boot_disk[0].initialize_params[0].image,
    ]
  }
}
