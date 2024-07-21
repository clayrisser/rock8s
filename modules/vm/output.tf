output "list" {
  value = [
    for host in proxmox_vm_qemu.vm : {
      "ip": host.ssh_host,
      # "ipv6": host.ipv6,
      "memory": host.memory,
      "name": host.name,
      "vcpus": host.vcpus,
    }
  ]
}
