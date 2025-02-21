resource "local_file" "env_output" {
  content  = <<-EOT
MASTER_IPS=${join(",", values(local.master_ips))}
WORKER_IPS=${join(",", values(local.worker_ips))}
MASTER_SSH_PRIVATE_KEY=${local.master_ssh_private_key}
MASTER_SSH_PUBLIC_KEY=${local.master_ssh_public_key}
WORKER_SSH_PRIVATE_KEY=${local.worker_ssh_private_key}
WORKER_SSH_PUBLIC_KEY=${local.worker_ssh_public_key}
EOT
  filename = local.env_output
}

output "master_ips" {
  value = local.master_ips
}

output "worker_ips" {
  value = local.worker_ips
}

output "master_private_ips" {
  value = local.master_private_ips
}

output "worker_private_ips" {
  value = local.worker_private_ips
}

output "env_output" {
  value = local.env_output
}

output "master_ssh_private_key" {
  value = local.master_ssh_private_key
}

output "worker_ssh_private_key" {
  value = local.worker_ssh_private_key
}
