# Replace Kubespray with k3sup — Shaping Notes

## Scope

Replace Kubespray (Ansible-based Kubernetes installer) with k3sup (lightweight Go binary) for all cluster lifecycle operations: install, upgrade, scale, reset, and node removal. This eliminates the Python/venv/Ansible dependency chain for the Kubernetes step while keeping Ansible for pfSense only.

## Decisions

- **k3sup over k3s-ansible**: k3sup (7.2k stars) is the most popular k3s deployment tool, requires no Python/Ansible, and integrates naturally with POSIX shell scripts
- **k3sup over Striveworks OpenTofu provider**: The OpenTofu provider (5 stars, v0.3.0, pre-1.0) is too immature for production use
- **Flannel over Calico**: k3s ships with Flannel (VXLAN) by default. Calico was only needed because Kubespray configured it. Flannel is simpler and k3s-native.
- **MetalLB to addons**: Currently configured via Kubespray vars.yml. Move to the existing addons Terraform flow.
- **pfSense stays on Ansible**: The marshallford/pfsense OpenTofu provider only covers ~10% of what the current Ansible roles do (no interfaces, NAT, HAProxy, CARP, HA sync). Not ready to replace Ansible.
- **k3sup as system dependency**: Like tofu, k3sup is expected to be installed on the host. No vendoring needed.

## Context

- **Visuals:** None
- **References:** Current kubespray integration in libexec/cluster/*.sh, kubespray/vars.yml
- **Product alignment:** N/A (no product folder)

## Standards Applied

- shell/posix-compliance — all new scripts must be POSIX /bin/sh
- shell/variable-naming — _PREFIX locals, ROCK8S_* globals, K3S_VERSION env
- providers/execution-model — k3sup runs after OpenTofu provisions nodes
- providers/purpose-based-infra — master/worker purpose dirs provide SSH keys and IPs
