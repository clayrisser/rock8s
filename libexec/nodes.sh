#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s nodes - manage cluster nodes

SYNOPSIS
       rock8s nodes <command> [<args>]

DESCRIPTION
       create and manage cluster nodes

OPTIONS
       -t, --tenant <tenant>
              tenant name (default: current user)

COMMANDS
       apply
              create new cluster nodes or update existing ones

       destroy
              destroy cluster nodes

SEE ALSO
       rock8s nodes apply --help
       rock8s nodes destroy --help
EOF
}

_main() {
    _FORMAT="${ROCK8S_OUTPUT_FORMAT:-text}"
    _CMD=""
    _CMD_ARGS=""
    _TENANT="$ROCK8S_TENANT"
    while test $# -gt 0; do
        case "$1" in
            -h|--help)
                _help
                exit 0
                ;;
            -t|--tenant|-t=*|--tenant=*)
                case "$1" in
                    *=*)
                        _TENANT="${1#*=}"
                        shift
                        ;;
                    *)
                        _TENANT="$2"
                        shift 2
                        ;;
                esac
                ;;
            apply|destroy)
                _CMD="$1"
                shift
                _CMD_ARGS="$*"
                break
                ;;
            *)
                _help
                exit 1
                ;;
        esac
    done
    if [ -z "$_CMD" ]; then
        _help
        exit 1
    fi
    export ROCK8S_TENANT="$_TENANT"
    _SUBCMD="$ROCK8S_LIB_PATH/libexec/nodes/$_CMD.sh"
    if [ ! -f "$_SUBCMD" ]; then
        _fail "unknown command: $_CMD"
    fi
    exec sh "$_SUBCMD" $_CMD_ARGS
}

_main "$@"
