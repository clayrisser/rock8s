#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s nodes ssh

SYNOPSIS
       rock8s nodes ssh [-h] [-c|--cluster <cluster>] [-t|--tenant <tenant>] (<purpose> <number> | <node_name> | <ip>) [<ssh_args>]

DESCRIPTION
       ssh into a specific node in the cluster

OPTIONS
       -h, --help
              display this help message and exit

       -o, --output=<format>
              output format (json, yaml, text)

       -c, --cluster <cluster>
              cluster name

       -t, --tenant <tenant>
              tenant name

       <purpose> <number>
              node purpose and number

       <node_name>
              full node name

       <ip>
              node ip address

       <ssh_args>
              additional arguments for ssh

EXAMPLE
       # ssh into the first master node
       rock8s nodes ssh master 1

       # ssh into a node by name
       rock8s nodes ssh master-1

       # ssh into a node by ip address
       rock8s nodes ssh 192.168.1.10

       # ssh with additional arguments
       rock8s nodes ssh master 1 -L 8080:localhost:8080

SEE ALSO
       rock8s nodes ls --help
       rock8s nodes apply --help
       rock8s nodes destroy --help
EOF
}

_show_available_nodes() {
    _PURPOSE="$1"
    if [ -n "$_PURPOSE" ]; then
        echo "Available ${_PURPOSE} nodes:" >&2
        sh "$ROCK8S_LIB_PATH/libexec/nodes/ls.sh" --cluster "$ROCK8S_CLUSTER" "$_PURPOSE" | cat >&2
    else
        echo "Available nodes:" >&2
        sh "$ROCK8S_LIB_PATH/libexec/nodes/ls.sh" --cluster "$ROCK8S_CLUSTER" | cat >&2
    fi
}

fail_with_nodes() {
    _MSG="$1"
    _PURPOSE="$2"
    echo "Error: $_MSG" >&2
    echo >&2
    _show_available_nodes "$_PURPOSE"
    exit 1
}

_count_nodes() {
    _NODE_TYPE="$1"
    case "$_NODE_TYPE" in
        master)
            get_master_private_ipv4s | wc -w
            ;;
        worker)
            get_worker_private_ipv4s | wc -w
            ;;
        pfsense)
            get_pfsense_private_ipv4s | wc -w
            ;;
    esac
}

_main() {
    _OUTPUT="${ROCK8S_OUTPUT}"
    _PURPOSE=""
    _NODE_NUM=""
    _NODE_IP=""
    _SSH_ARGS=""
    _CLUSTER="$ROCK8S_CLUSTER"
    _TENANT="$ROCK8S_TENANT"
    while test $# -gt 0; do
        case "$1" in
            -h|--help)
                _help
                exit 0
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
                if [ -n "$_PURPOSE" ]; then
                    if echo "$1" | grep -q '^[0-9]\+$'; then
                        _NODE_NUM="$1"
                        shift
                        if [ $# -gt 0 ]; then
                            _SSH_ARGS="$*"
                        fi
                        break
                    else
                        _help
                        exit 1
                    fi
                elif echo "$1" | grep -q '^[a-z]\+-[0-9]\+$'; then
                    _PURPOSE="${1%%-*}"
                    _NODE_NUM="${1##*-}"
                    case "$_PURPOSE" in
                        master|worker|pfsense) ;;
                        *) fail_with_nodes "invalid node name: $1 (must be master-N, worker-N, or pfsense-N)" ;;
                    esac
                    shift
                    if [ $# -gt 0 ]; then
                        _SSH_ARGS="$*"
                    fi
                    break
                elif echo "$1" | grep -q '^[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+$'; then
                    _NODE_IP="$1"
                    shift
                    if [ $# -gt 0 ]; then
                        _SSH_ARGS="$*"
                    fi
                    break
                else
                    _help
                    exit 1
                fi
                ;;
        esac
    done
    export ROCK8S_TENANT="$_TENANT"
    export ROCK8S_CLUSTER="$_CLUSTER"
    export ROCK8S_OUTPUT="$_OUTPUT"
    if [ -z "$ROCK8S_CLUSTER" ]; then
        fail "cluster name required"
    fi
    if [ -n "$_NODE_IP" ]; then
        _PRIVATE_IPS="$(get_master_private_ipv4s)"
        _COUNT=1
        for _IP in $_PRIVATE_IPS; do
            if [ "$_IP" = "$_NODE_IP" ]; then
                _PURPOSE="master"
                _NODE_NUM="$_COUNT"
                break
            fi
            _COUNT=$((_COUNT + 1))
        done
        if [ -z "$_PURPOSE" ]; then
            _PRIVATE_IPS="$(get_worker_private_ipv4s)"
            _COUNT=1
            for _IP in $_PRIVATE_IPS; do
                if [ "$_IP" = "$_NODE_IP" ]; then
                    _PURPOSE="worker"
                    _NODE_NUM="$_COUNT"
                    break
                fi
                _COUNT=$((_COUNT + 1))
            done
        fi
        if [ -z "$_PURPOSE" ]; then
            _PRIVATE_IPS="$(get_pfsense_private_ipv4s)"
            _COUNT=1
            for _IP in $_PRIVATE_IPS; do
                if [ "$_IP" = "$_NODE_IP" ]; then
                    _PURPOSE="pfsense"
                    _NODE_NUM="$_COUNT"
                    break
                fi
                _COUNT=$((_COUNT + 1))
            done
        fi
        [ -z "$_PURPOSE" ] && fail_with_nodes "no node found with ip $_NODE_IP"
    else
        [ -z "$_PURPOSE" ] && fail_with_nodes "node identifier required"
        if [ -z "$_NODE_NUM" ]; then
            _NODE_COUNT="$(_count_nodes "$_PURPOSE")"
            if [ "$_NODE_COUNT" -eq 1 ]; then
                _NODE_NUM=1
            else
                fail_with_nodes "node number required (found $_NODE_COUNT ${_PURPOSE} nodes)" "$_PURPOSE"
            fi
        fi
    fi
    case "$_PURPOSE" in
        master)
            _SSH_KEY="$(get_master_ssh_private_key)"
            _PRIVATE_IPS="$(get_master_private_ipv4s)"
            ;;
        worker)
            _SSH_KEY="$(get_worker_ssh_private_key)"
            _PRIVATE_IPS="$(get_worker_private_ipv4s)"
            ;;
        pfsense)
            _SSH_KEY="$(get_pfsense_ssh_private_key)"
            _PRIVATE_IPS="$(get_pfsense_private_ipv4s)"
            ;;
    esac
    [ -z "$_SSH_KEY" ] && fail_with_nodes "ssh key not found for $_PURPOSE nodes" "$_PURPOSE"
    if [ -z "$_NODE_IP" ]; then
        _NODE_IP="$(echo "$_PRIVATE_IPS" | tr ' ' '\n' | sed -n "${_NODE_NUM}p")"
        [ -z "$_NODE_IP" ] && fail_with_nodes "$_PURPOSE-$_NODE_NUM not found" "$_PURPOSE"
    fi
    exec ssh -i "$_SSH_KEY" "admin@$_NODE_IP" $_SSH_ARGS
}

_main "$@"
