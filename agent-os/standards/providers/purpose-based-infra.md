# Purpose-Based Infrastructure

## Cluster purposes

Each cluster has two purpose directories under cache:

```
$CLUSTER_DIR/
  master/      # control plane nodes — looks up existing network, creates firewall
  worker/      # worker nodes — looks up existing network and firewall
```

## Per-purpose isolation

Each purpose gets its own:
- State (local or remote backend, configured via `state:` in config)
- `TF_DATA_DIR` (`.terraform/` plugin cache)
- `terraform.tfvars.json`
- SSH key via `tls_private_key` OpenTofu resource (extracted to `id_rsa` after apply)
- `output.json` (OpenTofu outputs)

## Backend configuration

Backend is generated dynamically via `write_backend_config` based on `state.backend` in config:
- `local` (default) — state in purpose dir
- `s3` — requires `state.bucket`, `state.region`
- `gcs` — requires `state.bucket`
- `azblob` — requires `state.container`, `state.storage_account`

State key: `{cluster}/{purpose}/terraform.tfstate`

## Dependency order

Cluster: master first (creates firewall), then worker. Destroy is reverse.

## Resource naming

`local.cluster` = `var.cluster_name`
