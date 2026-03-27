# Config & State Layout

## XDG paths

```sh
ROCK8S_CONFIG_HOME  → ~/.config/rock8s        # user config
ROCK8S_CONFIG_DIRS  → colon-separated search   # layered config (user:system)
ROCK8S_STATE_HOME   → ~/.local/state/rock8s    # runtime state
ROCK8S_STATE_ROOT   → /var/lib/rock8s          # system-wide state
```

## Tenant/cluster hierarchy

```
$ROCK8S_STATE_HOME/
  current                          # sourced: sets tenant= and cluster=
  tenants/
    <tenant>/
      clusters/
        <cluster>/
          provider/                # copied provider code
          kube.yaml                # kubeconfig
          master/                  # purpose dir
            terraform.tfvars.json
            output.json
            id_rsa                 # extracted from state
          worker/                  # purpose dir
      pfsense/
        <name>/
          output.json
          id_rsa                   # extracted from state

$ROCK8S_CONFIG_HOME/
  config.yaml                      # base config (or use --config / ROCK8S_CONFIG)
  tenants/
    <tenant>/
      clusters/
        <cluster>/
          config.yaml              # cluster config (provider, nodes, addons, secrets via ref+)
```

## Layered config merge

`ROCK8S_CONFIG_DIRS` (colon-separated) merged left-to-right with `jq -s '.[0] * .[1]'`, then tenant `config.yaml` on top. Later wins.

## Current context

`$ROCK8S_STATE_HOME/current` is sourced to restore `tenant` and `cluster` from last `rock8s cluster use`.
