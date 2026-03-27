# pfSense Image Builder

This directory contains Packer configurations for building pfSense CE images for various platforms.

## Structure

- `pfsense.pkr.hcl` - Packer config for building pfSense qcow2 images via QEMU/KVM
- `Mkpmfile` - Build pipeline (download, pack, build, test)
- `scripts/` - Provisioning and initialization scripts

## Building Images

### Prerequisites

- Packer
- QEMU/KVM
- qemu-img (for format conversions)
- curl, gunzip

### Download pfSense ISO

```bash
make download
```

### Build qcow2 Image (Packer)

```bash
make pack
```

### Build All Formats

```bash
make build
```

Outputs:
- `.build/pfsense-2.7.2.qcow2` - QCOW2 image
- `.build/pfsense-2.7.2.raw` - Raw image (for Hetzner, AWS)
- `.build/pfsense-2.7.2.vhd` - VHD image (for Azure)
- `.build/pfsense-2.7.2-gcp.tar.gz` - GCP image
- `.build/pfsense-2.7.2-libvirt.box` - Vagrant box for libvirt
- `.build/pfsense-2.7.2-virtualbox.box` - Vagrant box for VirtualBox

### Run Tests

```bash
make test
```

## Using the Images

### Vagrant (Local Development)

```bash
make up
```

Or manually:

```bash
vagrant box add pfsense-2.7.2 .build/pfsense-2.7.2-libvirt.box
vagrant up --provider=libvirt
```

### Hetzner Cloud

```bash
hcloud image create --type snapshot --description "pfSense 2.7.2" \
  --name pfsense-2.7.2 --architecture x86 \
  .build/pfsense-2.7.2.raw
```

### Proxmox VE

```bash
qm create 9000 --name pfsense-template \
  --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0 \
  --scsihw virtio-scsi-pci --scsi0 local-lvm:0,import-from=.build/pfsense-2.7.2.qcow2
```

## Default Credentials

- **Web UI**: admin / pfsense
- **SSH**: root / pfsense
