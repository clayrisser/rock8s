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

Gateway (`network.gateway`) identifies the LAN router/firewall (e.g. pfSense). Cloud providers always keep their native public IPs; when a gateway is set, firewalls block all incoming traffic on the public interface (including SSH) so ingress flows through the LAN gateway instead. When omitted, nodes are WAN-only with SSH open on public IPs. On-prem providers (Proxmox, libvirt) are LAN-only; the gateway provides NAT for internet access. MetalLB assigns LAN IPs to LoadBalancer services.

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
- Secrets resolved at runtime via `ref+<scheme>://path` syntax
- Cache follows XDG conventions (`~/.cache/rock8s/`); all local state is regenerable
- OpenTofu state is offloaded to remote backends (S3, GCS, etc.)
- Cluster infrastructure is purpose-based: master → worker
- Provider code is copied per-apply for reproducibility
- Gateway/firewall is external — not managed by rock8s
