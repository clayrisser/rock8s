# Addon Registry

Addons are optional cluster components declared in the cluster config file.

## Addon IDs

snake_case: `external_dns`, `rancher_monitoring`, `cluster_issuer`, `argocd`, etc.

## Config shape in `config.yaml`

```yaml
addons:
  source:
    repo: https://gitlab.com/bitspur/rock8s/addons.git
    version: main
  longhorn: {}
  cert_manager: true
  external_dns:
    provider: cloudflare
    token: ...
  disabled_addon:          # empty key = disabled
```

- Simple toggle: `addon: true` or `addon: {}`
- Structured: nested config under the addon key
- Disabled: empty key (not `false`, not omitted) — every addon is always listed

## Container registries

Configured under `addons.registries` in the cluster config file.

Available registries: `docker.io`, `ghcr.io`, `registry.gitlab.com`, `public.ecr.aws`, `quay.io`.
