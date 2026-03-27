# Architecture Overview

rock8s is a CLI for provisioning and managing Kubernetes clusters on cloud infrastructure behind pfSense firewalls.

## Stack

| Layer | Technology |
|-------|-----------|
| CLI | POSIX `/bin/sh` |
| Kubernetes | k3s (via k3sup) |
| IaC | OpenTofu |
| Network gateway | pfSense (standalone, shared across clusters) |
| Config management | Ansible (pfSense only) |
| Load balancing | MetalLB (LAN IPs) + HAProxy (on pfSense) |
| Cloud providers | Hetzner (extensible) |

## Network model

All cluster nodes are LAN-only behind pfSense. No public IPs on master/worker nodes. Access via VPN on pfSense or direct LAN connection. Services exposed through HAProxy on pfSense. MetalLB assigns LAN IPs to LoadBalancer services.

## Repository layout

```
rock8s.sh              # entry point
libexec/               # CLI implementation (POSIX shell)
  lib/                 # shared libraries
  cluster/             # cluster subcommands
  nodes/               # node subcommands (master, worker)
  pfsense/             # pfsense subcommands (standalone)
  backup/              # backup drivers
providers/             # IaC per provider
  hetzner/             # OpenTofu modules + shell glue
  addons.sh            # addon registry
pfsense/               # Ansible roles for pfSense
  playbooks/
  roles/
  image/               # Packer/Vagrant for pfSense image building
```

## Key principles

- All shell is POSIX `/bin/sh` — no bashisms
- Config is layered YAML merged with jq
- State follows XDG conventions with tenant hierarchy
- Cluster infrastructure is purpose-based: master → worker
- pfSense is standalone shared infrastructure (one pfSense serves many clusters)
- Provider code is copied per-apply for reproducibility
- Interactive prompts via dialog, skippable with `NON_INTERACTIVE=1`
