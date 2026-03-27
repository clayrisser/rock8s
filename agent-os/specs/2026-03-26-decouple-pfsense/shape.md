# Decouple pfSense from Cluster Lifecycle — Shaping Notes

## Scope

Separate pfSense management from cluster provisioning. pfSense becomes standalone shared infrastructure that one or more clusters connect to. The cluster lifecycle (master/worker) assumes an existing pfSense and its LAN — never creates, configures, or destroys pfSense resources. All cluster access is LAN-only; nodes never have public IPs.

## Decisions

- **pfSense is required** — there is no "without pfSense" mode. The entire network model assumes nodes are behind pfSense on a private LAN.
- **pfSense is shared** — a single pfSense (or HA pair) can serve multiple clusters. pfSense state lives outside the cluster hierarchy.
- **LAN-only access** — master/worker nodes never get public IPs. Cluster access is via VPN on pfSense or direct LAN. No NAT toggle, no "external network" concept.
- **`rock8s pfsense` stays** — it configures existing pfSense appliances via SSH with Ansible (PHP scripts modifying XML), and supports HA (primary + secondary). No VM provisioning — pfSense is always an existing appliance with SSH access.
- **Cluster still publishes to pfSense** — after k3s install/upgrade, the cluster pushes HAProxy rules (ingress, kube-api) to the existing pfSense. This is the only cluster→pfSense coupling.
- **MetalLB is always enabled** — services get LAN IPs. HAProxy on pfSense forwards to MetalLB IPs, not individual worker IPs.
- **PHP-based Ansible approach** — pfSense configuration uses the proven check-then-configure pattern with PHP scripts that call pfSense's own APIs (`config.inc`, `config_set_path()`, `write_config()`). Not OPNsense. Restore from commit `d75ce15^`.
- **`pfsense` purpose removed from OpenTofu** — the provider module only handles `master` and `worker`. Network and route are created by the `master` purpose. No Packer image building.

## Context

- **Visuals:** None
- **References:** pfSense Ansible roles at git ref `d75ce15^`, current provider code in `providers/hetzner/`, current cluster lifecycle in `libexec/cluster/` and `libexec/nodes/`
- **Product alignment:** N/A (no product folder)

## Standards Applied

- shell/posix-compliance — all changes must stay POSIX sh
- shell/variable-naming — ROCK8S_* globals, _ prefix locals, TF_VAR_* for OpenTofu
- providers/execution-model — tfvars.sh/variables.sh flow unchanged for master/worker
- providers/purpose-based-infra — updated: cluster purposes are master/worker only; pfsense is standalone
- global/architecture — updated: pfSense is independent shared infrastructure
