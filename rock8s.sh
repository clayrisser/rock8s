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
: "${ROCK8S_TENANT:=default}"
: "${ROCK8S_OUTPUT:=text}"
export ROCK8S_CONFIG_DIRS
export ROCK8S_CONFIG_HOME
export ROCK8S_DEBUG
export ROCK8S_LIB_PATH
export ROCK8S_OUTPUT
export ROCK8S_STATE_HOME
export ROCK8S_STATE_ROOT
export ROCK8S_TENANT
export ANSIBLE_NOCOWS=1
. "$ROCK8S_LIB_PATH/libexec/lib.sh"

if [ "$(id -u)" = "0" ]; then
    fail "cannot run as root"
fi

_help() {
    cat <<EOF >&2
NAME
       rock8s

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
              output format

       -t, --tenant <tenant>
              tenant name

       -c, --cluster <cluster>
              cluster name

COMMANDS
       nodes
              create and manage cluster nodes

       cluster
              create kubernetes clusters

       pfsense
              configure and manage pfsense firewall

       completion
              generate shell completion scripts

EXAMPLE
       # create a cluster
       rock8s cluster configure --cluster mycluster --yes

       # list nodes in a cluster
       rock8s nodes ls --cluster mycluster

       # ssh into a worker node
       rock8s nodes ssh worker 1

       # use a specific tenant and output format
       rock8s -t mytenant -o yaml nodes ls

       # enable completions in your shell
       source <(rock8s completion)

SEE ALSO
       rock8s nodes --help
       rock8s cluster --help
       rock8s pfsense --help
       rock8s completion --help
EOF
}

_main() {
    _CMD=""
    _CMD_ARGS=""
    if [ -f "$ROCK8S_STATE_HOME/current" ]; then
        . "$ROCK8S_STATE_HOME/current"
        if [ -n "$tenant" ]; then
            export ROCK8S_TENANT="$tenant"
        fi
        if [ -n "$cluster" ]; then
            export ROCK8S_CLUSTER="$cluster"
        fi
    fi
    _CLUSTER="$ROCK8S_CLUSTER"
    _OUTPUT="$ROCK8S_OUTPUT"
    _TENANT="$ROCK8S_TENANT"
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
                        _OUTPUT="${1#*=}"
                        shift
                        ;;
                    *)
                        _OUTPUT="$2"
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
            -c|--cluster|-c=*|--cluster=*)
                case "$1" in
                    *=*)
                        _CLUSTER="${1#*=}"
                        shift
                        ;;
                    *)
                        _CLUSTER="$2"
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
            completion)
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
    export ROCK8S_CLUSTER="$_CLUSTER"
    export ROCK8S_OUTPUT="$_OUTPUT"
    _SUBCMD="$ROCK8S_LIB_PATH/libexec/$_CMD.sh"
    if [ ! -f "$_SUBCMD" ]; then
        fail "unknown command: $_CMD"
    fi
    exec sh "$_SUBCMD" $_CMD_ARGS
}

_main "$@"
