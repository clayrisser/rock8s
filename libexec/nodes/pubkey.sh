#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s nodes pubkey

SYNOPSIS
       rock8s nodes pubkey [-h] [-c|--cluster <cluster>] [-t|--tenant <tenant>] [<purpose>]

DESCRIPTION
       get public ssh key for nodes

OPTIONS
       -h, --help
              display this help message and exit

       -c, --cluster <cluster>
              cluster name

       -t, --tenant <tenant>
              tenant name

       <purpose>
              node purpose

EXAMPLE
       # get public key for master nodes
       rock8s nodes pubkey master

       # get public key for worker nodes
       rock8s nodes pubkey worker

       # get public key for all node types
       rock8s nodes pubkey

SEE ALSO
       rock8s nodes ls --help
       rock8s nodes ssh --help
       rock8s nodes apply --help
       rock8s nodes destroy --help
EOF
}

_main() {
    _PURPOSE=""
    _CLUSTER="$ROCK8S_CLUSTER"
    _TENANT="$ROCK8S_TENANT"
    while test $# -gt 0; do
        case "$1" in
            -h|--help)
                _help
                exit 0
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
            master|worker|pfsense)
                _PURPOSE="$1"
                shift
                ;;
            *)
                _help
                exit 1
                ;;
        esac
    done
    if [ -z "$_PURPOSE" ]; then
        _help
        exit 1
    fi
    export ROCK8S_TENANT="$_TENANT"
    export ROCK8S_CLUSTER="$_CLUSTER"
    if [ -z "$ROCK8S_CLUSTER" ]; then
        fail "cluster name required"
    fi
    _PURPOSE_DIR="$(get_cluster_dir)/$_PURPOSE"
    _PUBLIC_KEY_PATH="$_PURPOSE_DIR/id_rsa.pub"
    if [ -f "$_PUBLIC_KEY_PATH" ]; then
        cat "$_PUBLIC_KEY_PATH"
    else
        fail "no public key found for $_PURPOSE nodes"
    fi
}

_main "$@"
