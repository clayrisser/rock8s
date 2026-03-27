output "node_public_ipv4s" {
  value = local.node_public_ipv4s
}

output "node_private_ipv4s" {
  value = local.node_private_ipv4s
}

output "node_ssh_private_key" {
  value     = tls_private_key.node.private_key_pem
  sensitive = true
}

output "node_ssh_public_key" {
  value = tls_private_key.node.public_key_openssh
}

output "node_architectures" {
  value = local.node_architectures
}

output "network" {
  value = local.network
}
