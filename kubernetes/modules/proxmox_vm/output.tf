output "vm_list" {
  value = [
    for host in proxmox_vm_qemu.vm : {
      "name" : host.name
      "ip0" : host.ssh_host,
      "memory" : host.memory,
      "vcpus" : host.vcpus
    }
  ]
}
