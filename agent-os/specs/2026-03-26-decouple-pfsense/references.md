# References for Decouple pfSense from Cluster Lifecycle

## Internal References

### pfSense Ansible roles (PHP approach)

- **Git ref:** `d75ce15^` (commit before OPNsense transition)
- **Files:** `pfsense/roles/pfsense/tasks/*.yml`, `pfsense/roles/haproxy/tasks/*.yml`, `pfsense/roles/firewall/tasks/main.yml`
- **Relevance:** Proven PHP-based configuration approach. Each task writes a PHP script that uses pfSense's own APIs (`config.inc`, `config_set_path()`, `write_config()`) to modify `/cf/conf/config.xml`. Check-then-configure pattern ensures idempotency.
- **Covers:** dashboard, setup, system (althostnames), interfaces (LAN static/DHCP, IPv6), DHCP (v4+v6, kea backend), HA sync (CARP, pfsync, XMLRPC), routes, NAT (hybrid outbound), firewall rules (IPv4 via pfsensible.core, IPv6 via PHP), packages (haproxy, acme, pfBlockerNG), HAProxy (settings, VIPs, frontends, backends)
- **Dependencies:** `pfsensible.core >= 0.6.2`, `ansible.netcommon >= 2.5.0`

### Current cluster↔pfSense coupling

- **`libexec/nodes/apply.sh`** — enforces pfsense dir exists before master/worker (lines 154-168)
- **`libexec/nodes/destroy.sh`** — enforces destroy order: worker → master → pfsense (lines 148-160)
- **`libexec/cluster/apply.sh`** — orchestrates pfsense apply → nodes → pfsense publish → k3s (lines 167-216)
- **`libexec/pfsense/apply.sh`** — calls `nodes apply pfsense` then `configure.sh`
- **`libexec/pfsense/publish.sh`** — pushes HAProxy rules using cluster node IPs
- **`lib/pfsense.sh`** — 352 lines of helpers, reads from `$CLUSTER_DIR/pfsense/output.json`

### Provider code (Hetzner)

- **`providers/hetzner/main.tf`** — network/subnet/route created by `purpose == "master"`, data lookup for worker
- **`providers/hetzner/locals.tf`** — gateway IP calculated from subnet for default route
- **`providers/hetzner/variables.tf`** — purpose enum: `master`, `worker` only
- **`providers/hetzner/tfvars.sh`** — maps `masters`/`workers` config key to `nodes`
- **`providers/hetzner/config.sh`** — interactive config generator for cluster (masters/workers)
- **`providers/hetzner/pfsense_config.sh`** — interactive config for standalone pfSense (hostname + network only, no VM provisioning)

### Dead code enabled by LAN-only

- **`get_external_network()`** in `lib/network.sh` — returns "1" for hetzner, "0" otherwise; drives MetalLB/ingress branching
- **`get_lan_ipv4_nat()`** in `lib/network.sh` — reads `network.lan.ipv4.nat` config toggle
- **`get_master_public_ipv4s()` / `get_worker_public_ipv4s()`** — nodes never have public IPs
- **`bastion` argument in `libexec/cluster/login.sh`** — LAN-only means direct SSH to master private IP
- **`public_net` conditionals in `main.tf`** — master/worker always `ipv4_enabled = false`

## External References

- **pfsensible.core**: https://github.com/pfsensible/core (Ansible collection for pfSense)
- **pfSense config.xml**: https://docs.netgate.com/pfsense/en/latest/development/configuration.html
