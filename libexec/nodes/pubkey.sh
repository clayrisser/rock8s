#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s nodes pubkey

SYNOPSIS
       rock8s nodes pubkey [-h] [-c|--cluster <cluster>] <purpose>

DESCRIPTION
       get public ssh key for nodes

OPTIONS
       -h, --help
              display this help message and exit

       -o, --output=<format>
              output format (json, yaml, text)

       -c, --cluster <cluster>
              cluster name

       <purpose>
              node purpose (master or worker)

EXAMPLE
       # get public key for master nodes
       rock8s nodes pubkey master

       # get public key for worker nodes
       rock8s nodes pubkey worker

SEE ALSO
       rock8s nodes ls --help
       rock8s nodes ssh --help
       rock8s nodes apply --help
       rock8s nodes destroy --help
EOF
}

_main() {
    output="${ROCK8S_OUTPUT}"
    purpose=""
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
            _help
            exit 1
            ;;
        esac
    done
    if [ -z "$purpose" ]; then
        _help
        exit 1
    fi
    export ROCK8S_CLUSTER="$cluster"
    export ROCK8S_OUTPUT="$output"
    if [ -z "$ROCK8S_CLUSTER" ]; then
        fail "cluster name required"
    fi
    purpose_dir="$(get_cluster_dir)/$purpose"
    output_file="$purpose_dir/output.json"
    if [ -f "$output_file" ]; then
        public_key="$(jq -r '.node_ssh_public_key.value // empty' <"$output_file")"
        if [ -z "$public_key" ]; then
            fail "no public key found in output for $purpose nodes"
        fi
        printf '{"public_key":"%s"}\n' "$public_key" | format_output "$output"
    else
        fail "no output found for $purpose nodes"
    fi
}

_main "$@"
