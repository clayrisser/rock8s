#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s nodes ssh - ssh into a cluster node

SYNOPSIS
       rock8s nodes ssh [-h] [--cluster <cluster>] (<purpose> <number> | <node_name> | <ip>) [<ssh_args>]

DESCRIPTION
       SSH into a specific node in the cluster. The node can be specified in three ways:
       1. By purpose and number (e.g., master 1)
       2. By full node name (e.g., master-1)
       3. By IP address

       If only one node exists for the specified purpose, the number can be omitted.

OPTIONS
       -h, --help
              display this help message and exit

       --cluster <cluster>
              name of the cluster to manage

       <purpose> <number>
              node purpose and number:
              - master N  : ssh into master-N node
              - worker N  : ssh into worker-N node
              - pfsense N : ssh into pfsense-N node

       <node_name>
              full node name (e.g., master-1, worker-2, pfsense-1)

       <ip>
              node IP address

       <ssh_args>
              additional arguments to pass to ssh

EXAMPLES
       # SSH by purpose and number
       rock8s nodes ssh --cluster mycluster master 1
       rock8s nodes ssh --cluster mycluster worker 2
       rock8s nodes ssh --cluster mycluster pfsense 1

       # SSH by purpose only (when only one node exists)
       rock8s nodes ssh --cluster mycluster master    # connects to master-1 if it's the only master

       # SSH by node name
       rock8s nodes ssh --cluster mycluster master-1
       rock8s nodes ssh --cluster mycluster worker-2
       rock8s nodes ssh --cluster mycluster pfsense-1

       # SSH by IP
       rock8s nodes ssh --cluster mycluster 172.20.0.3

       # SSH with custom arguments
       rock8s nodes ssh --cluster mycluster master 1 -i ~/.ssh/custom_key
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
    _PURPOSE=""
    _NODE_NUM=""
    _NODE_IP=""
    _SSH_ARGS=""
    _CLUSTER="$ROCK8S_CLUSTER"
    while test $# -gt 0; do
        case "$1" in
            -h|--help)
                _help
                exit 0
                ;;
            --cluster|--cluster=*)
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
                        *) fail_with_nodes "Invalid node name: $1 (must be master-N, worker-N, or pfsense-N)" ;;
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
    export ROCK8S_CLUSTER="$_CLUSTER"
    if [ -z "$ROCK8S_CLUSTER" ]; then
        fail "cluster name required (use --cluster)"
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
        [ -z "$_PURPOSE" ] && fail_with_nodes "No node found with IP: $_NODE_IP"
    else
        [ -z "$_PURPOSE" ] && fail_with_nodes "Node identifier required (purpose+number, node name, or IP)"
        if [ -z "$_NODE_NUM" ]; then
            _NODE_COUNT="$(_count_nodes "$_PURPOSE")"
            if [ "$_NODE_COUNT" -eq 1 ]; then
                _NODE_NUM=1
            else
                fail_with_nodes "Node number required (found $_NODE_COUNT ${_PURPOSE} nodes)" "$_PURPOSE"
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
    [ -z "$_SSH_KEY" ] && fail_with_nodes "SSH key not found for $_PURPOSE nodes" "$_PURPOSE"
    if [ -z "$_NODE_IP" ]; then
        _NODE_IP="$(echo "$_PRIVATE_IPS" | tr ' ' '\n' | sed -n "${_NODE_NUM}p")"
        [ -z "$_NODE_IP" ] && fail_with_nodes "$_PURPOSE-$_NODE_NUM not found" "$_PURPOSE"
    fi
    exec ssh -i "$_SSH_KEY" "admin@$_NODE_IP" $_SSH_ARGS
}

_main "$@"
