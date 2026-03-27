#!/bin/sh

set -e

export ROCK8S_VERSION="0.2.0"

if [ -f "$(pwd)/lib/lib.sh" ]; then
    : "${ROCK8S_LIB_PATH:=$(pwd)/lib}"
    : "${ROCK8S_LIBEXEC_PATH:=$(pwd)/libexec}"
    ROCK8S_DEBUG=1
else
    : "${ROCK8S_LIB_PATH:=/usr/lib/rock8s}"
    : "${ROCK8S_LIBEXEC_PATH:=/usr/libexec/rock8s}"
    ROCK8S_DEBUG=0
fi
: "${ROCK8S_CACHE_HOME:=${XDG_CACHE_HOME:-$HOME/.cache}/rock8s}"
: "${ROCK8S_OUTPUT:=text}"
: "${ROCK8S_CONFIG:=}"
export ROCK8S_DEBUG
export ROCK8S_LIB_PATH
export ROCK8S_LIBEXEC_PATH
export ROCK8S_OUTPUT
export ROCK8S_CACHE_HOME
export ROCK8S_CONFIG
export ANSIBLE_NOCOWS=1
. "$ROCK8S_LIB_PATH/lib.sh"

if [ "$(id -u)" = "0" ]; then
    fail "cannot run as root"
fi

_version() {
    while test $# -gt 0; do
        case "$1" in
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
        *)
            shift
            ;;
        esac
    done
    printf '{"version":"%s"}\n' "$ROCK8S_VERSION" | format_output "$output"
}

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

       -c, --cluster <cluster>
              cluster name

       --config <path>
              path to config file (default: rock8s.yaml in current directory)

COMMANDS
       init
              initialize a new rock8s configuration file

       nodes
              create and manage cluster nodes

       cluster
              create kubernetes clusters

       kubectl
              run kubectl commands using the cluster's kube.yaml file

       completion
              generate shell completion scripts

       version
              display rock8s version information

EXAMPLE
       # create a cluster
       rock8s cluster addons --cluster mycluster --yes

       # list nodes in a cluster
       rock8s nodes ls --cluster mycluster

       # ssh into a worker node
       rock8s nodes ssh worker 1

       # run kubectl commands using the cluster's kube.yaml file
       rock8s kubectl get pods

       # enable completions in your shell
       source <(rock8s completion)

       # show version information
       rock8s version

SEE ALSO
       rock8s nodes --help
       rock8s cluster --help
       rock8s kubectl --help
       rock8s completion --help
       rock8s version --help
EOF
}

_kubectl() {
    cluster_dir="$(get_cluster_dir)"
    kube_config="$cluster_dir/kube.yaml"
    if [ ! -f "$kube_config" ]; then
        fail "kube.yaml not found at $kube_config"
    fi
    kubectl --kubeconfig="$kube_config" "$@"
}

_main() {
    cmd=""
    cmd_args=""
    cluster="$ROCK8S_CLUSTER"
    output="$ROCK8S_OUTPUT"
    config="$ROCK8S_CONFIG"
    while test $# -gt 0; do
        case "$1" in
        -h | --help)
            _help
            exit
            ;;
        -d | --debug)
            ROCK8S_DEBUG=1
            shift
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
        --config | --config=*)
            case "$1" in
            *=*)
                config="${1#*=}"
                shift
                ;;
            *)
                config="$2"
                shift 2
                ;;
            esac
            ;;
        init | nodes | cluster)
            cmd="$1"
            shift
            cmd_args="$*"
            break
            ;;
        kubectl)
            shift
            _kubectl "$@"
            exit $?
            ;;
        completion)
            cmd="$1"
            shift
            cmd_args="$*"
            break
            ;;
        version)
            shift
            _version "$@"
            exit
            ;;
        *)
            _help
            exit 1
            ;;
        esac
    done
    if [ -z "$cmd" ]; then
        _help
        exit 1
    fi
    export ROCK8S_CLUSTER="$cluster"
    export ROCK8S_OUTPUT="$output"
    export ROCK8S_CONFIG="$config"
    subcmd="$ROCK8S_LIBEXEC_PATH/$cmd.sh"
    if [ ! -f "$subcmd" ]; then
        fail "unknown command: $cmd"
    fi
    exec sh "$subcmd" $cmd_args
}

_main "$@"
