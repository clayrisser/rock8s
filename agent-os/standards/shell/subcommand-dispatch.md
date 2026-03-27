# Subcommand Dispatch

CLI entry: `rock8s.sh` → `libexec/<group>.sh` → `libexec/<group>/<cmd>.sh`

## Dispatch chain

1. `rock8s.sh` parses global flags (`-o`, `-c`, `-t`), matches command name, `exec sh` to router
2. Router (`cluster.sh`, `nodes.sh`, `pfsense.sh`) parses group-level flags, matches subcommand, `exec sh` to command script
3. Command script (`cluster/init.sh`, `nodes/apply.sh`, etc.) does the actual work

```sh
_SUBCMD="$ROCK8S_LIB_PATH/libexec/<group>/$_CMD.sh"
if [ ! -f "$_SUBCMD" ]; then
    fail "unknown command: $_CMD"
fi
exec sh "$_SUBCMD" $_CMD_ARGS
```

- Use `exec sh` — replaces the process, no subshell overhead
- Every script starts with `#!/bin/sh` and `set -e`
- Every script sources `lib.sh` for shared functions

## Adding a new subcommand

1. Create `libexec/<group>/<cmd>.sh`
2. Add `_help()` with man-page sections (NAME, SYNOPSIS, DESCRIPTION, OPTIONS)
3. Add dispatch case in `libexec/<group>.sh`
4. `_help()` heredocs are mined by `manpages.sh` to generate roff man pages — format matters

## Help function format

```sh
_help() {
    cat <<EOF >&2
NAME
       rock8s <group> <cmd>

SYNOPSIS
       rock8s <group> <cmd> [OPTIONS]

DESCRIPTION
       What it does.

OPTIONS
       -h, --help    Show this help message
       -o, --output  Output format (text, json, yaml)

SEE ALSO
       rock8s <group> <other-cmd> --help
EOF
}
```

- Always write to stderr (`>&2`)
- `-h`/`--help` exits 0; missing subcommand runs `_help` then exits 1

## Option parsing

Support both `--flag value` and `--flag=value`:

```sh
-o|--output|-o=*|--output=*)
    case "$1" in
        *=*) _OUTPUT="${1#*=}"; shift ;;
        *)   _OUTPUT="$2"; shift 2 ;;
    esac
    ;;
```
