# Addon Registry

Addons are optional cluster components managed via `providers/addons.sh`.

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

## Default set

A curated default list is used when `ADDONS` env is unset. Normalized from multiline string with `tr '\n' ' ' | xargs`.

## Container registries

Prompted as multiselect from allowlist: `docker.io`, `ghcr.io`, `registry.gitlab.com`, `public.ecr.aws`, `quay.io`.

## GitLab heuristic

If addon repo URL contains `gitlab.com` **and** registries include `gitlab.com`, git auth prompts are skipped (assumes registry auth covers it).
