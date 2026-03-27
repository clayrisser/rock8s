# Standards for Replace Kubespray with k3sup

The following standards apply to this work.

---

## shell/posix-compliance

All shell scripts MUST be POSIX-compliant `/bin/sh`.

- Shebang: `#!/bin/sh`
- No bashisms: no arrays, no `[[ ]]`, no `read -a`, no `${var,,}`, no `<<<`
- Use `[ ]` not `[[ ]]` for tests
- Use `$(cmd)` not backticks
- Parameter expansion only: `${var:-default}`, `${var#pattern}`, `${var%pattern}`
- No `local` keyword — use `_` prefix convention
- Every script begins with `#!/bin/sh` and `set -e`

---

## shell/variable-naming

- Environment globals: prefix with `ROCK8S_` (e.g. `ROCK8S_CLUSTER`)
- Script-local variables: prefix with `_` (e.g. `_CLUSTER_DIR`)
- Boolean flags: string `"0"` / `"1"`
- Defaults: `${K3S_VERSION:-v1.31.4+k3s1}`
- Infrastructure variables: `TF_VAR_*` for OpenTofu

---

## providers/execution-model

- Provider code is copied per-apply into cluster state
- Variable flow: config.yaml → get_config_json → jq merge → tfvars.sh → terraform.tfvars.json
- k3sup runs after OpenTofu provisions nodes, using IPs and SSH keys from OpenTofu outputs

---

## providers/purpose-based-infra

- Each cluster has purpose directories: pfsense → master → worker
- Each purpose gets its own SSH keypair, state, and outputs
- Dependency order: pfsense first, then master, then worker
- k3sup uses master SSH keys for server nodes, worker SSH keys for agent nodes
