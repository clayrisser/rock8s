# Standards for Decouple pfSense from Cluster Lifecycle

The following standards apply to this work.

---

## shell/posix-compliance

All shell scripts MUST be POSIX-compliant `/bin/sh`.

- Shebang: `#!/bin/sh`
- No bashisms: no arrays, no `[[ ]]`, no `read -a`, no `${var,,}`, no `<<<`
- Use `[ ]` not `[[ ]]` for tests
- No `local` keyword — use `_` prefix convention
- Every script begins with `#!/bin/sh` and `set -e`

---

## shell/variable-naming

- `ROCK8S_*` for env globals
- `_` prefix for script-locals
- `TF_VAR_*` for OpenTofu variables
- Boolean flags as `"0"` / `"1"` strings

---

## providers/execution-model

Provider source in `providers/<name>/` copied per-apply to `$CLUSTER_DIR/provider/`.

Variable flow: `config.yaml` → `get_config_json` → `tfvars.sh` (stdin JSON → stdout JSON) → `terraform.tfvars.json` + `variables.sh` (sourced) + `TF_VAR_*` exports.

---

## providers/purpose-based-infra

**Updated for this spec:** cluster purposes are `master` and `worker` only. pfSense is standalone shared infrastructure with its own state directory outside the cluster hierarchy.

Cluster state:
```
$CLUSTER_DIR/
  master/      # control plane nodes — looks up existing network
  worker/      # worker nodes — looks up existing firewall
```

pfSense state:
```
$STATE_HOME/tenants/<tenant>/pfsense/<name>/
  output.json
  vars.yml
  hosts.yml
  ansible/
  collections/
```

Cluster dependency order: master first (creates firewall), then worker. Destroy is reverse.

---

## global/architecture

Stack: POSIX shell CLI, k3s (via k3sup), OpenTofu, Ansible (pfSense only), Hetzner cloud.

Network model: all nodes are LAN-only behind pfSense. No public IPs on cluster nodes. Access via VPN or LAN. Services exposed through HAProxy on pfSense. MetalLB assigns LAN IPs to LoadBalancer services.
