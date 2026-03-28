# Config & Cache Layout

## Config discovery

Config is found in order:
1. `--config /path/to/rock8s.yaml` (explicit flag or `ROCK8S_CONFIG` env var)
2. `rock8s.yaml` in the current working directory

If neither exists, the CLI fails with a clear error.

## XDG paths

```sh
ROCK8S_CACHE_HOME   → ~/.cache/rock8s          # local cache (fully regenerable)
```

## Cache hierarchy

All local data is cached and regenerable. OpenTofu state is offloaded to remote backends (S3, GCS, etc.) defined in config.

```
$ROCK8S_CACHE_HOME/
  clusters/
    <cluster>/
      provider/                # copied provider code
      kube.yaml                # kubeconfig
      master/                  # purpose dir
        terraform.tfvars.json
        output.json
        id_rsa                 # extracted from terraform output
      worker/                  # purpose dir
      addons/                  # addons terraform + artifacts
```
