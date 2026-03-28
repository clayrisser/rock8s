# Provider Execution Model

## Provider code copy

Provider source lives in `providers/<name>/` but is **copied** per-apply into cluster state:

```
$CLUSTER_DIR/provider/    # fresh copy of providers/<name>/
```

This ensures each cluster uses the provider code version from when it was last applied.

## Variable flow

```
rock8s.yaml → get_config_json → resolve_refs → jq merge → tfvars.sh (stdin JSON → stdout JSON) → terraform.tfvars.json
                                                          → variables.sh (sourced for provider secrets)
                                                          → TF_VAR_* exports (identity vars)
```

### `tfvars.sh`

- Reads JSON on **stdin**, reshapes it, writes JSON to **stdout**
- Purpose-specific: maps `master` → `.masters`, `worker` → `.workers`
- Strips keys OpenTofu doesn't need (`.provider`, `.registries`, `.addons`)

### `variables.sh`

- **Sourced** (not piped) — sets `TF_VAR_*` for provider API tokens
- Cloud-init user data is now generated in OpenTofu locals (uses `tls_private_key` public key)

## State & SSH keys

- SSH keys managed by `tls_private_key` resource in OpenTofu state
- Private key extracted from `tofu output` after apply via `extract_ssh_private_key`
- Backend configured dynamically via `write_backend_config` (local, s3, gcs, azblob)
- `terraform.tfvars.json`: `chmod 600` (contains secrets)
