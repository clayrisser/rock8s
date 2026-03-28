# rock8s v2 Architecture — Shaping Notes

## Scope

Complete architectural rewrite of rock8s core. No backward compatibility with v1.

## Decisions

- Config is a single YAML file, checked into git, containing everything except secret provider credentials
- No interactive prompts — config must be valid or it fails
- Secrets resolved at runtime via `ref+<provider>://path` syntax in config values
- Secret provider credentials come from environment variables (AWS_ACCESS_KEY_ID, VAULT_TOKEN, etc.)
- OpenTofu state backend configurable (local or S3/GCS/Azure) from config `state:` section
- SSH keys managed as OpenTofu resources (in state), not local files
- pfSense fully decoupled — managed in a separate project/repo
- Gateway is the LAN router/firewall — cloud nodes keep public IPs (firewalled when gateway set), on-prem uses NAT
- k3s replaces kubespray
- Multi-arch: provider exports arch hints, runtime fallback via `uname -m`
- All shell remains POSIX `/bin/sh` compliant

## Secret Providers

| Scheme | CLI | Resolution |
|--------|-----|------------|
| `ref+env` | (none) | environment variable |
| `ref+file` | (none) | file contents |
| `ref+pass` | `pass` | `pass show <path>` |
| `ref+kms` | `aws` | `aws kms decrypt` |
| `ref+secretsmanager` | `aws` | `aws secretsmanager get-secret-value` |
| `ref+ssm` | `aws` | `aws ssm get-parameter --with-decryption` |
| `ref+vault` | `vault` | `vault kv get` |
| `ref+gcsm` | `gcloud` | `gcloud secrets versions access` |
| `ref+azkeyvault` | `az` | `az keyvault secret show` |

Fragment (`#key`) extracts a field from JSON responses.

## Config Model

```yaml
provider:
  type: hetzner
  token: ref+secretsmanager://rock8s/hetzner-token
state:
  backend: local    # or s3, gcs, azblob
network:
  entrypoint: cluster.example.com
  gateway: 172.20.0.2
  lan:
    ipv4:
      subnet: 172.20.0.0/16
masters:
  - type: cx32
    count: 3
workers:
  - type: cpx51
    count: 3
addons:
  longhorn: {}
  cluster_issuer: {}
```

## Context

- **Visuals:** None
- **References:** Existing v1 codebase, helmfile/vals ref+ convention
- **Product alignment:** N/A
