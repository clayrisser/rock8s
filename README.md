# yams

> scripts to deploy proxmox

## Install

### I. Boot Proxmox Installer

SSH into a recovery machine as root and run the following command to boot up the installer.

```sh
$(curl --version >/dev/null 2>/dev/null && echo curl -fL || echo wget --content-on-error -O-) \
    https://gitlab.com/bitspur/rock8s/yams/-/raw/main/scripts/01_boot-installer.sh 2>/dev/null | sh
```

### II. Install Proxmox

After the installer has booted, connect to the server using VNC and following the installation
instructions. When the installation has completed and rebooted, shutdown the virtual machine with `CTRL-C`.

### III. Boot Proxmox

Run the following command from the recovery machine to boot into the newly installed system.

```sh
$(curl --version >/dev/null 2>/dev/null && echo curl -fL || echo wget --content-on-error -O-) \
    https://gitlab.com/bitspur/rock8s/yams/-/raw/main/scripts/02_boot.sh 2>/dev/null | sh
```

### IV. Login

SSH into a new session of the recovery machine as root and run the following command to SSH into the proxmox system.

```sh
$(curl --version >/dev/null 2>/dev/null && echo curl -fL || echo wget --content-on-error -O-) \
    https://gitlab.com/bitspur/rock8s/yams/-/raw/main/scripts/03_login.sh 2>/dev/null | sh
```

### V. Post Install

From inside the proxmox system, run the following command to run the post installation. Make
sure to provide a password for the admin account.

```sh
$(curl --version >/dev/null 2>/dev/null && echo curl -fL || echo wget --content-on-error -O-) \
    https://gitlab.com/bitspur/rock8s/yams/-/raw/main/scripts/04_post-install.sh 2>/dev/null | sh
```

### VI. Reboot

Power off the the proxmox system and then reboot the recovery system. Make sure to wait for the
proxmox system to fully power off.

### VII. Setup

SSH into the proxmox system as admin and run the following setup script.

```sh
$(curl --version >/dev/null 2>/dev/null && echo curl -fL || echo wget --content-on-error -O-) \
    https://gitlab.com/bitspur/rock8s/yams/-/raw/main/scripts/05_setup.sh 2>/dev/null | sh
```
