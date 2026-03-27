# Standards for OpenTofu Migration

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

Three purpose directories: `pfsense/`, `master/`, `worker/` — each with own state, `TF_DATA_DIR`, tfvars, SSH keys, outputs. Applied in order, destroyed in reverse.

---

## global/architecture

Stack: POSIX shell CLI, k3s (replacing kubespray), OpenTofu (replacing Terraform), Ansible for pfSense, Hetzner cloud.
