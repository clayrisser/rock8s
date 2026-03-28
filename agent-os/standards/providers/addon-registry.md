# Addon Registry

Addons are optional cluster components declared in the cluster config file.

## Addon IDs

snake_case: `external_dns`, `rancher_monitoring`, `cluster_issuer`, `argocd`, etc.

## Config shape in `rock8s.yaml`

```yaml
addons:
  longhorn: {}
  cluster_issuer: {}
  external_dns:
    provider: cloudflare
    token: ...
  disabled_addon:          # empty key = disabled
```

- Simple toggle: `addon: {}` (empty object)
- Structured: nested config under the addon key
- Disabled: empty key (not `false`, not omitted) — every addon is always listed

## Addon source

Override the default addons Terraform module source with `addons.source`:

```yaml
addons:
  source:
    repo: https://github.com/example/rock8s-addons.git
    version: v1.2.0
```

- `addons.source.repo` — git URL for the addons module (defaults to the bundled `addons/` directory)
- `addons.source.version` — git ref (tag, branch, or commit) to pin the addons module version

## Container registries

Configured under `addons.registries` in the cluster config file.

Available registries: `docker.io`, `ghcr.io`, `registry.gitlab.com`, `public.ecr.aws`, `quay.io`.
