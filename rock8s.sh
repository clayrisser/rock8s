#!/bin/sh

set -e

if [ -f "$(pwd)/libexec/lib.sh" ]; then
    : "${ROCK8S_LIB_PATH:=$(pwd)}"
    ROCK8S_DEBUG=1
else
    : "${ROCK8S_LIB_PATH:=/usr/lib/rock8s}"
    ROCK8S_DEBUG=0
fi
: "${ROCK8S_CONFIG_HOME:=${XDG_CONFIG_HOME:-$HOME/.config}/rock8s}"
: "${ROCK8S_CONFIG_DIRS:=$ROCK8S_CONFIG_HOME:${XDG_CONFIG_DIRS:-/etc}/rock8s}"
: "${ROCK8S_STATE_HOME:=${XDG_STATE_HOME:-$HOME/.local/state}/rock8s}"
: "${ROCK8S_STATE_ROOT:=/var/lib/rock8s}"
export ANSIBLE_NOCOWS=1
export ROCK8S_CONFIG_HOME
export ROCK8S_CONFIG_DIRS
export ROCK8S_DEBUG
export ROCK8S_LIB_PATH
export ROCK8S_STATE_HOME
export ROCK8S_STATE_ROOT
. "$ROCK8S_LIB_PATH/libexec/lib.sh"

if [ "$(id -u)" = "0" ]; then
    _fail "cannot run as root"
fi

_help() {
    cat <<EOF >&2
NAME
       rock8s - kubernetes cluster management cli

SYNOPSIS
       rock8s [-h] [-d] [-o <format>] <command> [<args>]

DESCRIPTION
       create and manage kubernetes clusters

OPTIONS
       -h, --help
              show this help message

       -d, --debug
              debug mode

       -o, --output=<format>
              output format (default: json)
              supported formats: text, json, yaml

       -t, --tenant <tenant>
              tenant name (default: current user)

COMMANDS
       nodes
              create and manage cluster nodes

       cluster
              create kubernetes clusters

       pfsense
              configure and manage pfSense firewall

SEE ALSO
       rock8s nodes --help
       rock8s cluster --help
       rock8s pfsense --help
EOF
}

_main() {
    _FORMAT="json"
    _CMD=""
    _CMD_ARGS=""
    _TENANT="$ROCK8S_TENANT"
    if [ -z "$_TENANT" ]; then
        _TENANT="default"
    fi
    while test $# -gt 0; do
        case "$1" in
            -h|--help)
                _help
                exit 0
                ;;
            -d|--debug)
                ROCK8S_DEBUG=1
                shift
                ;;
            -o|--output|-o=*|--output=*)
                case "$1" in
                    *=*)
                        _FORMAT="${1#*=}"
                        shift
                        ;;
                    *)
                        _FORMAT="$2"
                        shift 2
                        ;;
                esac
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
            nodes|cluster|pfsense)
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
    export ROCK8S_OUTPUT_FORMAT="$_FORMAT"
    _SUBCMD="$ROCK8S_LIB_PATH/libexec/$_CMD.sh"
    if [ ! -f "$_SUBCMD" ]; then
        _fail "unknown command: $_CMD"
    fi
    exec sh "$_SUBCMD" $_CMD_ARGS
}

_main "$@"
