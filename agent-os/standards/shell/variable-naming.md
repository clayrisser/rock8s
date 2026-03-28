# Variable Naming

## Environment globals

Exported variables prefixed with `ROCK8S_`:

```sh
ROCK8S_CACHE_HOME
ROCK8S_CLUSTER
ROCK8S_CONFIG
ROCK8S_DEBUG
ROCK8S_LIB_PATH
ROCK8S_LIBEXEC_PATH
ROCK8S_OUTPUT
ROCK8S_VERSION
```

## Script-level variables

File-scope vars, memoization caches, and state shared across functions.
Prefix with `_`, use `ALL_CAPS`:

```sh
_ENSURED_SYSTEM
_CLUSTER_DIR
_CONFIG_JSON
_PROVIDER
_OLM_VERSION
```

- No `local` keyword (not POSIX)
- `_` prefix prevents collisions with env vars and child scripts
- Memoized getter caches (`_CLUSTER_DIR`, `_CONFIG_JSON`, etc.) use this tier

## Function-local variables

Parameters, loop iterators, and temp values used within a single function.
Use `lower_case`, no prefix:

```sh
output
cluster
cmd
line
i
```

## Boolean flags

Use string `"0"` / `"1"`:

```sh
yes="0"
force="0"
skip_k3s="0"

if [ "$yes" = "1" ]; then ...
```

## Defaults

Use parameter expansion with `:` assignment:

```sh
: "${ROCK8S_OUTPUT:=text}"
: "${RETRIES:=3}"
```

## Infrastructure variables

- `TF_VAR_*` for OpenTofu variables
