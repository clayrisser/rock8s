resource "tls_private_key" "node" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "google_compute_network" "lan" {
  count = var.purpose == "master" ? 1 : 0

  description                     = "rock8s cluster ${var.cluster_name} LAN (custom VPC)"
  name                            = local.vpc_name
  auto_create_subnetworks         = false
  delete_default_routes_on_create = false
  mtu                             = try(var.network.lan.mtu, 1460)
}

data "google_compute_network" "lan" {
  count = var.purpose == "worker" ? 1 : 0

  name = local.vpc_name
}

resource "google_compute_subnetwork" "lan" {
  count = var.purpose == "master" ? 1 : 0

  description = "rock8s cluster ${var.cluster_name} primary subnet in ${var.location}"
  name        = local.subnet_name
  region      = var.location
  network     = google_compute_network.lan[0].id

  ip_cidr_range            = var.network.lan.ipv4.subnet
  private_ip_google_access = local.has_gateway
}

data "google_compute_subnetwork" "lan" {
  count = var.purpose == "worker" ? 1 : 0

  name   = local.subnet_name
  region = var.location
}

# Default internet egress for nodes with external IPs (custom VPC has no implicit route).
resource "google_compute_route" "default_internet" {
  count = var.purpose == "master" && !local.has_gateway ? 1 : 0

  description      = "rock8s ${var.cluster_name}: default egress via internet gateway (nodes use external IPs)"
  name             = "${local.cluster}-default-internet"
  dest_range       = "0.0.0.0/0"
  network          = google_compute_network.lan[0].id
  priority         = 1000
  next_hop_gateway = "default-internet-gateway"
}

# Single-homed private nodes: send 0.0.0.0/0 to the customer gateway on the LAN.
resource "google_compute_route" "via_gateway" {
  count = var.purpose == "master" && local.has_gateway ? 1 : 0

  description = "rock8s ${var.cluster_name}: default route via customer gateway ${local.gateway_ip}"
  name        = "${local.cluster}-via-gateway"
  dest_range  = "0.0.0.0/0"
  network     = google_compute_network.lan[0].id
  priority    = 100
  next_hop_ip = local.gateway_ip
}

resource "google_compute_firewall" "internal" {
  count = var.purpose == "master" ? 1 : 0

  description = "rock8s ${var.cluster_name}: allow full east-west traffic on the LAN subnet"
  name        = "${local.cluster}-internal"
  network     = google_compute_network.lan[0].name

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

  description = "rock8s ${var.cluster_name}: SSH to nodes with external IPs (restrict in production)"
  name        = "${local.cluster}-ssh-public"
  network     = google_compute_network.lan[0].name

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
  network            = google_compute_network.lan[0].name
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
    network    = var.purpose == "master" ? google_compute_network.lan[0].id : data.google_compute_network.lan[0].id
    subnetwork = var.purpose == "master" ? google_compute_subnetwork.lan[0].id : data.google_compute_subnetwork.lan[0].id
    network_ip = local.node_configs[count.index].network_ip

    dynamic "access_config" {
      for_each = local.has_gateway ? [] : [1]
      content {
        network_tier = "PREMIUM"
      }
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
