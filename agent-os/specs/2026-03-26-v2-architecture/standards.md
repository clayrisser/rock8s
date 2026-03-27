# Standards for rock8s v2

## shell/posix-compliance

All shell scripts MUST be POSIX-compliant `/bin/sh`. No bashisms.

## shell/variable-naming

- `ROCK8S_*` for env globals, `_` prefix for script-locals
- `TF_VAR_*` for OpenTofu variables
- Boolean flags as `"0"` / `"1"` strings

## shell/subcommand-dispatch

CLI dispatch chain via `exec sh`. `_help()` with man-page sections. Option parsing supports both `--flag value` and `--flag=value`.

## providers/execution-model

Provider code copied per-apply. `tfvars.sh` reads JSON stdin, emits JSON stdout. `variables.sh` sourced for secrets.
