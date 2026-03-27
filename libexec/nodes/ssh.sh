#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s nodes ssh

SYNOPSIS
       rock8s nodes ssh [-h] [-c|--cluster <cluster>] (<purpose> <number> | <node_name> | <ip>) [<ssh_args>]

DESCRIPTION
       ssh into a specific node in the cluster

OPTIONS
       -h, --help
              display this help message and exit

       -o, --output=<format>
              output format (json, yaml, text)

       -c, --cluster <cluster>
              cluster name

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
    purpose="$1"
    if [ -n "$purpose" ]; then
        echo "Available ${purpose} nodes:" >&2
        sh "$ROCK8S_LIBEXEC_PATH/nodes/ls.sh" --cluster "$ROCK8S_CLUSTER" "$purpose" >&2
    else
        echo "Available nodes:" >&2
        sh "$ROCK8S_LIBEXEC_PATH/nodes/ls.sh" --cluster "$ROCK8S_CLUSTER" >&2
    fi
}

fail_with_nodes() {
    msg="$1"
    purpose="$2"
    echo "Error: $msg" >&2
    echo >&2
    _show_available_nodes "$purpose"
    exit 1
}

_count_nodes() {
    node_type="$1"
    case "$node_type" in
    master)
        get_master_private_ipv4s | wc -w
        ;;
    worker)
        get_worker_private_ipv4s | wc -w
        ;;
    esac
}

_main() {
    output="${ROCK8S_OUTPUT}"
    purpose=""
    node_num=""
    node_ip=""
    ssh_args=""
    cluster="$ROCK8S_CLUSTER"
    while test $# -gt 0; do
        case "$1" in
        -h | --help)
            _help
            exit
            ;;
        -o | --output | -o=* | --output=*)
            case "$1" in
            *=*)
                output="${1#*=}"
                shift
                ;;
            *)
                output="$2"
                shift 2
                ;;
            esac
            ;;
        -c | --cluster | -c=* | --cluster=*)
            case "$1" in
            *=*)
                cluster="${1#*=}"
                shift
                ;;
            *)
                cluster="$2"
                shift 2
                ;;
            esac
            ;;
        master | worker)
            purpose="$1"
            shift
            ;;
        *)
            if [ -n "$purpose" ]; then
                if echo "$1" | grep -q '^[0-9]\+$'; then
                    node_num="$1"
                    shift
                    if [ $# -gt 0 ]; then
                        ssh_args="$*"
                    fi
                    break
                else
                    _help
                    exit 1
                fi
            elif echo "$1" | grep -q '^[a-z]\+-[0-9]\+$'; then
                purpose="${1%%-*}"
                node_num="${1##*-}"
                case "$purpose" in
                master | worker) ;;
                *) fail_with_nodes "invalid node name: $1 (must be master-N or worker-N)" ;;
                esac
                shift
                if [ $# -gt 0 ]; then
                    ssh_args="$*"
                fi
                break
            elif echo "$1" | grep -q '^[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+$'; then
                node_ip="$1"
                shift
                if [ $# -gt 0 ]; then
                    ssh_args="$*"
                fi
                break
            else
                _help
                exit 1
            fi
            ;;
        esac
    done
    export ROCK8S_CLUSTER="$cluster"
    export ROCK8S_OUTPUT="$output"
    if [ -z "$ROCK8S_CLUSTER" ]; then
        fail "cluster name required"
    fi
    if [ -n "$node_ip" ]; then
        private_ips="$(get_master_private_ipv4s)"
        count=1
        for _IP in $private_ips; do
            if [ "$_IP" = "$node_ip" ]; then
                purpose="master"
                node_num="$count"
                break
            fi
            count=$((count + 1))
        done
        if [ -z "$purpose" ]; then
            private_ips="$(get_worker_private_ipv4s)"
            count=1
            for _IP in $private_ips; do
                if [ "$_IP" = "$node_ip" ]; then
                    purpose="worker"
                    node_num="$count"
                    break
                fi
                count=$((count + 1))
            done
        fi
        [ -z "$purpose" ] && fail_with_nodes "no node found with ip $node_ip"
    else
        [ -z "$purpose" ] && fail_with_nodes "node identifier required"
        if [ -z "$node_num" ]; then
            node_count="$(_count_nodes "$purpose")"
            if [ "$node_count" -eq 1 ]; then
                node_num=1
            else
                fail_with_nodes "node number required (found $node_count ${purpose} nodes)" "$purpose"
            fi
        fi
    fi
    case "$purpose" in
    master)
        ssh_key="$(get_master_ssh_private_key)"
        private_ips="$(get_master_private_ipv4s)"
        ;;
    worker)
        ssh_key="$(get_worker_ssh_private_key)"
        private_ips="$(get_worker_private_ipv4s)"
        ;;
    esac
    [ -z "$ssh_key" ] && fail_with_nodes "ssh key not found for $purpose nodes" "$purpose"
    if [ -z "$node_ip" ]; then
        node_ip="$(echo "$private_ips" | tr ' ' '\n' | sed -n "${node_num}p")"
        [ -z "$node_ip" ] && fail_with_nodes "$purpose-$node_num not found" "$purpose"
    fi
    exec ssh -i "$ssh_key" "$(get_node_ssh_user)@$node_ip" $ssh_args
}

_main "$@"
