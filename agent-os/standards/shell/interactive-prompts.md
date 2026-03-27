# Config-First (No Interactive Prompts)

## Design

rock8s v2 operates in config-first mode. There are no interactive prompts. If required configuration is missing or invalid, the CLI fails immediately with a clear error message.

## Config file

A single YAML config file is the source of truth:

```sh
# Specify via flag
rock8s --config /path/to/rock8s.yaml cluster apply

# Or via environment variable
ROCK8S_CONFIG=/path/to/rock8s.yaml rock8s cluster apply

# Or use the default location
# rock8s.yaml (in current directory or via --config)
```

## Secret references

Secrets are resolved at runtime via `ref+` URI syntax in config values:

```yaml
provider:
  type: hetzner
  token: ref+secretsmanager://rock8s/hetzner-token
```

Supported schemes: `ref+env`, `ref+file`, `ref+pass`, `ref+kms`, `ref+secretsmanager`, `ref+ssm`, `ref+vault`, `ref+gcsm`, `ref+azkeyvault`.

Fragment (`#key`) extracts a field from JSON responses.

## Fail-fast behavior

- Missing config file → fail with path
- Missing required field → fail with field name
- Invalid `ref+` scheme → fail with scheme
- Secret provider CLI not installed → fail with tool name
- Secret fetch error → fail with provider and path
