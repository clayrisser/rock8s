# yaps

> yet another proxmox script

## ISO Install

### I. Boot Proxmox Installer

SSH into a recovery machine as root and run the following command to boot up the installer.

```sh
$(curl --version >/dev/null 2>/dev/null && echo curl -fL || echo wget --content-on-error -O-) \
    https://gitlab.com/bitspur/rock8s/yaps/-/raw/main/scripts/iso/01_boot-installer.sh 2>/dev/null > 01_boot-installer.sh
sh 01_boot-installer.sh
rm 01_boot-installer.sh
```

### II. Install Proxmox

After the installer has booted, connect to the server using VNC and following the installation
instructions. When the installation has completed and rebooted, shutdown the virtual machine with `CTRL-C`.

### III. Boot Proxmox

Run the following command from the recovery machine to boot into the newly installed system.

```sh
$(curl --version >/dev/null 2>/dev/null && echo curl -fL || echo wget --content-on-error -O-) \
    https://gitlab.com/bitspur/rock8s/yaps/-/raw/main/scripts/iso/02_boot.sh > 02_boot.sh
sh 02_boot.sh
rm 02_boot.sh
```

### IV. Login

SSH into a new session of the recovery machine as root and run the following command to SSH into the proxmox system.

```sh
$(curl --version >/dev/null 2>/dev/null && echo curl -fL || echo wget --content-on-error -O-) \
    https://gitlab.com/bitspur/rock8s/yaps/-/raw/main/scripts/iso/03_login.sh > 03_login.sh
sh 03_login.sh
rm 03_login.sh
```

### V. Post Install

From inside the proxmox system, run the following command to run the post installation. Make
sure to provide a password for the admin account.

```sh
$(curl --version >/dev/null 2>/dev/null && echo curl -fL || echo wget --content-on-error -O-) \
    https://gitlab.com/bitspur/rock8s/yaps/-/raw/main/scripts/post-install.sh > post-install.sh
sh post-install.sh
rm post-install.sh
```

### VI. Reboot

Power off the the proxmox system and then reboot the recovery system. Make sure to wait for the
proxmox system to fully power off.

### VII. Setup

SSH into the proxmox system as admin and run the following setup script.

```sh
make -sC ~/yaps setup
```

### VIII. Deploy Kubernetes

SSH into the proxmox system as admin and run the following setup script.

```sh
$(curl --version >/dev/null 2>/dev/null && echo curl -fL || echo wget --content-on-error -O-) \
    https://gitlab.com/bitspur/rock8s/yaps/-/raw/main/scripts/deploy_kubernetes.sh > deploy_kubernetes.sh
sh deploy_kubernetes.sh
rm deploy_kubernetes.sh
```

## Debian Install

### I. Prepare Debian

Prepare a fresh Debian system.

### II. Install Proxmox

Run the following command to install proxmox.

```sh
$(curl --version >/dev/null 2>/dev/null && echo curl -fL || echo wget --content-on-error -O-) \
    https://gitlab.com/bitspur/rock8s/yaps/-/raw/main/scripts/debian/01_install.sh > 01_install.sh
sh 01_install.sh
rm 01_install.sh
```

### III. Post Install

From inside the proxmox system, run the following command to run the post installation. Make
sure to provide a password for the admin account.

```sh
$(curl --version >/dev/null 2>/dev/null && echo curl -fL || echo wget --content-on-error -O-) \
    https://gitlab.com/bitspur/rock8s/yaps/-/raw/main/scripts/post-install.sh > post-install.sh
sh post-install.sh
rm post-install.sh
```

### IV. Reboot

Power off the the proxmox system and then reboot the recovery system. Make sure to wait for the
proxmox system to fully power off.

### V. Setup

SSH into the proxmox system as admin and run the following setup script.

```sh
make -sC ~/yaps setup
```

### VI. Deploy Kubernetes

SSH into the proxmox system as admin and run the following setup script.

```sh
make -sC ~/yaps kubernetes/apply
```

## PFSense Install

### Setup

1. Install pfsense from the iso
2. Set the WAN to `vtnet1` and the LAN to `vtnet0`
3. Set WAN interface ip addresses
4. Disable the firewall `pfctl -d`
5. Go to the WAN gateway ip and login with user `admin` and password `pfsense`

### Network Topology

| description           | ip                          | hostname                       |
| --------------------- | --------------------------- | ------------------------------ |
| LAN primary gateway   | `172.20.0.1`                | `access-primary.bitspur.com`   |
| LAN secondary gateway | `172.20.0.2`                | `access-secondary.bitspur.com` |
| LAN DHCP range        | `172.20.1.1-172.20.255.254` |                                |

## Commands

### Debugging

#### Failed Services

```sh
sudo systemctl --failed
```

#### Reset Failed Services

```sh
sudo systemctl reset-failed
```

### Networking

#### List Networks

```sh
sudo ip addr
```

#### List Routes

```sh
sudo ip route
sudo ip -6 route
```

#### List Bridges

```sh
sudo brctl ???
```

#### Restart

```sh
sudo systemctl restart networking
```

### Disks

#### List

```sh
sudo lsblk
```

#### Clear

```sh
sudo sfdisk --delete /dev/<ID>
sudo wipefs -af /dev/<ID>
```

### Logs

#### System Logs

```sh
sudo journalctl -xef
```

#### Hardware Logs

```sh
sudo dmesg
```
