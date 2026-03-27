---
name: Replace kubespray with k3sup
overview: "Replace Kubespray (Ansible-based Kubernetes installer) with k3sup (lightweight Go binary) for all cluster lifecycle operations: install, upgrade, scale, reset, and node removal. This eliminates the Python/venv/Ansible dependency chain entirely."
todos:
  - id: save-spec
    content: Save spec documentation to agent-os/specs/ (plan.md, shape.md, standards.md, references.md)
    status: in_progress
  - id: create-k3s-lib
    content: Create lib/k3s.sh with helper functions, update lib/lib.sh to source it
    status: pending
  - id: rewrite-cluster-sh
    content: "Update libexec/cluster.sh: replace KUBESPRAY_VERSION/KUBESPRAY_REPO with K3S_VERSION/K3S_CHANNEL"
    status: pending
  - id: rewrite-install
    content: Rewrite libexec/cluster/install.sh using k3sup install + join
    status: pending
  - id: rewrite-upgrade
    content: Rewrite libexec/cluster/upgrade.sh for k3s upgrade via SSH
    status: pending
  - id: rewrite-scale
    content: Rewrite libexec/cluster/scale.sh using k3sup join
    status: pending
  - id: rewrite-reset
    content: Rewrite libexec/cluster/reset.sh using SSH + k3s-uninstall.sh
    status: pending
  - id: rewrite-node-rm
    content: Rewrite libexec/cluster/node/rm.sh using kubectl drain/delete + SSH uninstall
    status: pending
  - id: update-apply
    content: "Update libexec/cluster/apply.sh: rename --skip-kubespray to --skip-k3s"
    status: pending
  - id: update-destroy
    content: "Update libexec/nodes/destroy.sh: remove kubespray cleanup references"
    status: pending
  - id: update-makefile
    content: "Update Makefile: remove kubespray directory install targets"
    status: pending
  - id: remove-kubespray-dir
    content: Remove kubespray/ directory (vars.yml, postinstall.yml) and lib/kubespray.sh
    status: pending
  - id: update-standards
    content: Update agent-os/standards/ docs and project-words.txt
    status: pending
isProject: false
---

# Replace Kubespray with k3sup

## Context

Currently, `rock8s cluster install/upgrade/scale/reset/node rm` all work by cloning the upstream Kubespray repo (v2.24.0) at runtime, creating a Python venv, installing Ansible, generating inventory files, and running `ansible-playbook` against various Kubespray playbooks. This is slow, brittle, and heavyweight.

k3sup is a single Go binary (7k+ stars, MIT, actively maintained since 2019) that installs k3s over SSH. It replaces the entire Kubespray flow with simple CLI calls that can be wrapped in POSIX shell scripts.

## Architecture Change

```mermaid
flowchart LR
    subgraph before [Before]
        A1["cluster install"] --> B1["git clone kubespray"]
        B1 --> C1["python3 -m venv"]
        C1 --> D1["pip install requirements"]
        D1 --> E1["generate inventory.ini"]
        E1 --> F1["generate vars.yml"]
        F1 --> G1["ansible-playbook cluster.yml"]
        G1 --> H1["ansible-playbook postinstall.yml"]
    end
    subgraph after [After]
        A2["cluster install"] --> B2["k3sup install --cluster"]
        B2 --> C2["k3sup join --server (HA masters)"]
        C2 --> D2["k3sup join (workers)"]
    end
```

## Key Decisions

- **CNI**: Switch from Calico (Kubespray) to Flannel (k3s default, also VXLAN). Simpler, k3s-native, no extra configuration needed.
- **Built-in addons**: k3s includes metrics-server by default. Disable Traefik and ServiceLB via `--disable traefik --disable servicelb` (the existing addons flow handles ingress/LB).
- **MetalLB**: Move from Kubespray vars to the existing addons Terraform flow.
- **cert-manager, dashboard**: Move from Kubespray vars to the existing addons Terraform flow.
- **TLS SANs**: `supplementary_addresses_in_ssl_keys` maps directly to `--tls-san` flag.
- **postinstall.yml**: The hook that runs `/tmp/postinstall.sh` if present can be replaced by a simple SSH command after install.
- **k3sup dependency**: Add k3sup as a system requirement (like tofu/terraform). No vendoring needed -- it's a single static binary.

## Feature Mapping: Kubespray vars.yml to k3s

| Kubespray var | k3s equivalent |
|---|---|
| `kube_version: v1.28.6` | `K3S_VERSION` env var / `--k3s-version` flag |
| `kube_network_plugin: calico` | Flannel (k3s default) |
| `calico_network_backend: vxlan` | `--flannel-backend=vxlan` (default) |
| `calico_mtu` / `calico_veth_mtu` | Flannel auto-detects MTU |
| `metallb_enabled` + config | Move to addons Terraform |
| `cert_manager_enabled` | Move to addons Terraform |
| `dashboard_enabled` | Move to addons Terraform |
| `helm_enabled` | k3s includes helm controller by default |
| `metrics_server_enabled` | k3s includes metrics-server by default |
| `supplementary_addresses_in_ssl_keys` | `--tls-san` per address |
| `nat_outgoing` / `nat_outgoing_ipv6` | Flannel handles NAT by default |
| `enable_dual_stack_networks` | `--cluster-cidr` + `--service-cidr` with dual CIDRs |

## Files to Change

### Remove

- [kubespray/vars.yml](kubespray/vars.yml) -- entire file
- [kubespray/postinstall.yml](kubespray/postinstall.yml) -- entire file
- [lib/kubespray.sh](lib/kubespray.sh) -- replaced by k3s.sh

### Rewrite

- [libexec/cluster/install.sh](libexec/cluster/install.sh) -- k3sup install + join flow
- [libexec/cluster/upgrade.sh](libexec/cluster/upgrade.sh) -- SSH-based k3s upgrade
- [libexec/cluster/scale.sh](libexec/cluster/scale.sh) -- k3sup join for new nodes
- [libexec/cluster/reset.sh](libexec/cluster/reset.sh) -- SSH + k3s-uninstall.sh
- [libexec/cluster/node/rm.sh](libexec/cluster/node/rm.sh) -- kubectl drain/delete + SSH uninstall

### Modify

- [libexec/cluster.sh](libexec/cluster.sh) -- replace `KUBESPRAY_VERSION`/`KUBESPRAY_REPO` with `K3S_VERSION`/`K3S_CHANNEL`
- [libexec/cluster/apply.sh](libexec/cluster/apply.sh) -- rename `--skip-kubespray` to `--skip-k3s`, update `_SKIP_KUBESPRAY` to `_SKIP_K3S`
- [lib/lib.sh](lib/lib.sh) -- source `lib/k3s.sh` instead of `lib/kubespray.sh`
- [libexec/nodes/destroy.sh](libexec/nodes/destroy.sh) -- update cleanup: `rm -rf "$_CLUSTER_DIR/kubespray"` no longer needed
- [Makefile](Makefile) -- remove `kubespray` install directory and copy targets

### Create

- `lib/k3s.sh` -- helper functions (e.g. `get_k3s_extra_args`, build `--tls-san` list)

### Update Standards/Docs

- [agent-os/standards/global/architecture.md](agent-os/standards/global/architecture.md) -- update stack table (Kubespray -> k3sup), update repo layout
- [agent-os/standards/shell/variable-naming.md](agent-os/standards/shell/variable-naming.md) -- `_SKIP_KUBESPRAY` example -> `_SKIP_K3S`
- [agent-os/standards/providers/purpose-based-infra.md](agent-os/standards/providers/purpose-based-infra.md) -- remove Kubespray migration note
- [project-words.txt](project-words.txt) -- add k3sup, k3s

## install.sh Sketch

```sh
K3S_VERSION="${K3S_VERSION:-v1.31.4+k3s1}"

_MASTER_IPS="$(get_master_private_ips)"
_FIRST_MASTER="$(echo "$_MASTER_IPS" | head -1)"
_MASTER_SSH_KEY="$(get_master_ssh_private_key)"
_WORKER_IPS="$(get_worker_private_ips)"
_WORKER_SSH_KEY="$(get_worker_ssh_private_key)"
_TLS_SANS="$(get_supplementary_addresses)"
_EXTRA_ARGS="--disable traefik --disable servicelb"
_DUAL_STACK="$(get_enable_network_dualstack)"

# Install first server (HA init)
k3sup install \
  --ip "$_FIRST_MASTER" \
  --user admin \
  --ssh-key "$_MASTER_SSH_KEY" \
  --cluster \
  --k3s-version "$K3S_VERSION" \
  --k3s-extra-args "$_EXTRA_ARGS --tls-san $_TLS_SANS" \
  --local-path "$(get_cluster_dir)/kube.yaml"

# Join remaining masters
for _IP in $(echo "$_MASTER_IPS" | tail -n +2); do
  k3sup join --ip "$_IP" --server-ip "$_FIRST_MASTER" \
    --user admin --ssh-key "$_MASTER_SSH_KEY" \
    --server --k3s-version "$K3S_VERSION" \
    --k3s-extra-args "$_EXTRA_ARGS"
done

# Join workers
for _IP in $_WORKER_IPS; do
  k3sup join --ip "$_IP" --server-ip "$_FIRST_MASTER" \
    --user admin --ssh-key "$_WORKER_SSH_KEY" \
    --k3s-version "$K3S_VERSION"
done
```

## reset.sh Sketch

```sh
# Uninstall agents first, then servers
for _IP in $_WORKER_IPS; do
  ssh -i "$_WORKER_SSH_KEY" admin@"$_IP" \
    "/usr/local/bin/k3s-agent-uninstall.sh" 2>/dev/null || true
done
for _IP in $_MASTER_IPS; do
  ssh -i "$_MASTER_SSH_KEY" admin@"$_IP" \
    "/usr/local/bin/k3s-uninstall.sh" 2>/dev/null || true
done
```

## node/rm.sh Sketch

```sh
export KUBECONFIG="$(get_cluster_dir)/kube.yaml"
kubectl drain "$_NODE" --ignore-daemonsets --delete-emptydir-data --force
kubectl delete node "$_NODE"
# Then SSH to uninstall the agent
ssh -i "$_SSH_KEY" admin@"$_NODE_IP" "/usr/local/bin/k3s-agent-uninstall.sh"
```

## Risk Mitigation

- **k3sup availability**: k3sup is a dependency like tofu. If it's missing, `install.sh` should `fail "k3sup is required"` early.
- **Flannel vs Calico**: Flannel is simpler and k3s-native. If Calico is needed later, it can be installed via `--flannel-backend=none` + addon.
- **MTU**: Flannel auto-detects MTU. If custom MTU is needed, pass `--flannel-iface` or configure via k3s config file.
- **Dual-stack**: k3s supports dual-stack via `--cluster-cidr 10.42.0.0/16,fd00:42::/56 --service-cidr 10.43.0.0/16,fd00:43::/112`.
- **postinstall hook**: If still needed, replace with a simple SSH loop after install.
