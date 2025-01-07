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

### VII. Create Proxmox and Ceph Cluster with CephFS

Details on how to create the proxmox cluster and ceph cluster are beyond the scope of these docs.
Make sure that a cephfs filesystem called `cephfs` is created.

You can learn more about how to setup a proxmox and ceph cluster at the following links.

https://www.virtualizationhowto.com/2024/01/cephfs-configuration-in-proxmox-step-by-step
https://rdr-it.io/en/proxmox-configure-a-cluster-with-ceph-storage

### VIII. Setup

SSH into the proxmox system as admin and run the following setup script.

```sh
make -sC ~/yaps setup
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

### V. Create Proxmox and Ceph Cluster

Details on how to create the proxmox cluster and ceph cluster are beyond the scope of these docs.
Make sure that a cephfs filesystem called `cephfs` is created.

You can learn more about how to setup a proxmox and ceph cluster at the following links.

https://www.virtualizationhowto.com/2024/01/cephfs-configuration-in-proxmox-step-by-step
https://rdr-it.io/en/proxmox-configure-a-cluster-with-ceph-storage

### VI. Setup

SSH into the proxmox system as admin and run the following setup script.

```sh
make -sC ~/yaps setup
```

## Additional Applications

After setting up proxmox, the following applications are highly recommended.

### PFSense

#### Setup

1. Install pfsense from the iso
2. Set the WAN to `vtnet1` and the LAN to `vtnet0`
3. Set WAN interface ip addresses
4. Disable the firewall `pfctl -d`
5. Go to the WAN gateway ip and login with user `admin` and password `pfsense`

#### Network Topology

| description        | ipv4                        | ipv6           |
| ------------------ | --------------------------- | -------------- |
| LAN virtual        | `172.20.0.1`                | `fd00::20:0:1` |
| LAN primary        | `172.20.0.2`                | `fd00::20:0:2` |
| LAN secondary      | `172.20.0.3`                | `fd00::20:0:3` |
| LAN static range   | `172.20.1.1-172.20.1.254`   |                |
| LAN DHCP range     | `172.20.2.1-172.20.9.254`   |                |
| LAN metallb ranges | `172.20.10.1-172.20.99.254` |                |
| SYNC primary       | `172.22.0.1`                |                |
| SYNC secondary     | `172.22.0.2`                |                |

### Powerdns

```sh
make powerdns
```

### Radosgw

```sh
make radosgw
```

### Kubernetes

```sh
make kubernetes
```

## Reference

### DNS Servers

#### IPV4

| ip        | provider   |
| --------- | ---------- |
| `8.8.8.8` | google     |
| `8.8.4.4` | google     |
| `1.1.1.1` | cloudflare |

#### IPV6

| ip                     | provider |
| ---------------------- | -------- |
| `2001:4860:4860::8888` | google   |
| `2001:4860:4860::8844` | google   |

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

#### Trace Routes

```sh
traceroute -n 8.8.8.8
```

```sh
traceroute6 -n 2001:4860:4860::8888
```

### Networking

#### Validate Interfaces Config

```sh
sudo ifup --no-act --all
```

#### List Networks

```sh
sudo ip addr
```

#### List Routes

```sh
sudo ip route
sudo ip -6 route
```

#### Network Interface Status

```sh
ethtool <NIC>
```

#### List Bridges

```sh
sudo brctl show
```

#### Restart

```sh
sudo systemctl restart networking
```

### Broken Cluster

#### Force Stop VMs

```sh
for vm in $(sudo qm list | tail -n+2 | awk '{print $1}'); do
    sudo qm stop $vm --timeout 15 # --skiplock
done
```

#### Reset Quorum

```sh
sudo pvecm expected "$(sudo pvecm status | grep -E '^Total votes:' | sed 's|.* ||g')"
```

#### Restart Services

```sh
sudo systemctl restart corosync
sudo systemctl restart ceph-mon*
sudo systemctl restart ceph-mgr*
sudo systemctl restart ceph-mds*
sudo systemctl restart ceph-osd*
sudo systemctl restart ceph-radosgw*
sudo systemctl restart ceph-crash
sudo systemctl restart pve-cluster
sudo systemctl restart pve-ha-crm
sudo systemctl restart pve-ha-lrm
sudo systemctl restart pve-lxc-syscalld
sudo systemctl restart pvedaemon
sudo systemctl restart pvefw-logger
sudo systemctl restart pveproxy
sudo systemctl restart pvescheduler
sudo systemctl restart pvestatd
```

### Disks

#### Resize

```sh
$(curl --version >/dev/null 2>/dev/null && echo curl -fL || echo wget --content-on-error -O-) \
    https://gitlab.com/bitspur/rock8s/yaps/-/raw/main/scripts/resize.sh 2>/dev/null | sh
```

#### List

```sh
sudo lsblk
```

#### Clear

```sh
SUDO="$(which sudo >/dev/null 2>&1 && echo sudo || true)"
for d in $(lsblk -dn -o NAME | grep -E "^nvme" | sort); do
    echo "\$SUDO sfdisk --delete /dev/$d"
    echo "\$SUDO wipefs -af /dev/$d"
done
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

### Ceph

List orphaned volumes

_WARNING: this only finds orphaned volumes against a single kubernetes cluster_

```sh
(kubectl get pv -o json | jq -r '.items[].spec.csi.volumeAttributes.imageName' && (sudo rbd ls | grep -E "^csi")) | sort | uniq -u
```

### Removed Dead Node

1. remove the node references from the ceph config
    ```sh
    sudo vim /etc/ceph/ceph.conf
    ```

2. remove the node references from the keyring
    ```sh
    sudo vim /etc/ceph/ceph.client.radosgw.keyring
    ```

3. remove the node references from ceph
    ```sh
    NODE_ID=pve#
    sudo systemctl restart ceph-mds.target
    sudo systemctl restart ceph-mgr.target
    sudo systemctl restart ceph-mon.target
    sudo ceph mon remove $NODE_ID
    sudo ceph mgr fail $NODE_ID
    sudo ceph auth del mgr.$NODE_ID
    sudo ceph auth del mds.$NODE_ID
    sudo ceph auth del client.radosgw.$NODE_ID
    ```
4. remove osds from crush map
    ```sh
    sudo ceph osd crush remove osd.#
    ```

5. reset the services on each node
    ```sh
    sudo systemctl restart ceph-mds.target
    sudo systemctl restart ceph-mgr.target
    sudo systemctl restart ceph-mon.target
    sudo systemctl restart pveproxy
    sudo systemctl restart pvedaemon
    sudo systemctl restart pve-cluster
    ```

6. delete the node reference
    ```sh
    NODE_ID=pve#
    sudo pvecm delnode $NODE_ID
    sudo rm -rf /etc/pve/nodes/$NODE_ID
    sudo systemctl restart corosync
    sudo systemctl restart pve-cluster
    sudo pvecm expected "$(sudo pvecm status | grep -E '^Total votes:' | sed 's|.* ||g')"
    ```
