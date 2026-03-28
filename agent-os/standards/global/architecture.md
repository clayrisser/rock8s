# Architecture Overview

rock8s is a CLI for provisioning and managing Kubernetes clusters on cloud infrastructure.

## Stack

| Layer | Technology |
|-------|-----------|
| CLI | POSIX `/bin/sh` |
| Kubernetes | k3s (via k3sup) |
| IaC | OpenTofu |
| Load balancing | MetalLB (LAN IPs) |
| Cloud providers | Hetzner, AWS, Azure, GCP, DigitalOcean, OVH, Vultr, libvirt, Proxmox |

## Network model

Cloud VMs use the provider VPC/private network for east-west traffic and a public IP for reachability. Terraform-managed firewalls allow SSH from the internet so k3sup/SSH provisioning works; tighten rules in the cloud console if you expose production clusters. On-prem providers (Proxmox, libvirt) use cloud images on your LAN/NAT as you configure outside rock8s. Optional `network.lan.metallb` documents a pool for in-cluster LoadBalancer services when you use MetalLB (or similar).

## Repository layout

```
rock8s.sh              # entry point
lib/                   # sourced shell libraries (/usr/lib/rock8s)
  lib.sh               # library loader
  utils.sh, config.sh  # shared functions
libexec/               # executed subcommands (/usr/libexec/rock8s)
  cluster/             # cluster subcommands
  nodes/               # node subcommands (master, worker)
providers/             # IaC per provider
  hetzner/             # OpenTofu modules + shell glue
```

## Key principles

- All shell is POSIX `/bin/sh` — no bashisms
- Config is a single YAML file (`rock8s.yaml`), checked into git
- Secrets resolved at runtime via `ref+<scheme>://path` syntax; optional `.env` merge fills `ref+env` keys without overriding existing exports (see shell standards)
- Cache follows XDG conventions (`~/.cache/rock8s/`); all local state is regenerable
- OpenTofu state is offloaded to remote backends (S3, GCS, etc.)
- Cluster infrastructure is purpose-based: master → worker
- Provider code is copied per-apply for reproducibility
- Upstream corporate firewalls and edge NAT are outside rock8s — only node-level rules in Terraform are defined here
