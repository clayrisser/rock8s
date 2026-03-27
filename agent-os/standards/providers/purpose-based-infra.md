# Purpose-Based Infrastructure

## Cluster purposes

Each cluster has two purpose directories under state:

```
$CLUSTER_DIR/
  master/      # control plane nodes — looks up existing network, creates firewall
  worker/      # worker nodes — looks up existing network and firewall
```

## pfSense (standalone)

pfSense is shared infrastructure, independent of any cluster. One pfSense instance can serve multiple clusters.

```
$STATE_HOME/tenants/<tenant>/pfsense/<name>/
  output.json
  terraform.tfstate
  vars.yml
  hosts.yml
  ansible/
  collections/
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

State key: `{tenant}/{cluster}/{purpose}/terraform.tfstate`

## Existing pfSense support

When `pfsense[].type` is absent in config, pfSense is treated as an existing appliance:
- `pfsense apply` skips node provisioning, only runs configure
- `pfsense destroy` skips infrastructure destruction, only cleans state

## Dependency order

Cluster: master first (creates firewall), then worker. Destroy is reverse.

pfSense: independent, must be provisioned before any cluster that uses its network.

## Resource naming

`local.cluster` = `cluster_name` or `tenant-cluster_name` (skips tenant prefix when tenant is `default`).
