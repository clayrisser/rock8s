#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s cluster apply

SYNOPSIS
       rock8s cluster apply [-h] [-o <format>] [--cluster <cluster>] [-t <tenant>] [--update] [-y|--yes] [--skip-kubespray] [--skip-pfsense] [--skip-nodes] [--pfsense-password <password>] [--pfsense-ssh-password]

DESCRIPTION
       create nodes, install and configure kubernetes cluster in a single command

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format

       -t, --tenant <tenant>
              tenant name

       -c, --cluster <cluster>
              cluster name

       --update
              update ansible collections

       -y, --yes
              skip confirmation prompt

       --skip-kubespray
              skip kubespray installation

       --skip-pfsense
              skip pfsense installation

       --skip-nodes
              skip nodes installation

       --pfsense-password <password>
              admin password for pfsense

       --pfsense-ssh-password
              use password authentication for ssh with pfsense

EXAMPLE
       # apply a cluster with automatic approval
       rock8s cluster apply --cluster mycluster --yes

       # apply a cluster with a specific tenant and pfsense password
       rock8s cluster apply --cluster mycluster --tenant mytenant --pfsense-password mypassword

SEE ALSO
       rock8s cluster install --help
       rock8s cluster addons --help
       rock8s cluster upgrade --help
EOF
}

_main() {
    _OUTPUT="${ROCK8S_OUTPUT}"
    _TENANT="$ROCK8S_TENANT"
    _CLUSTER="$ROCK8S_CLUSTER"
    _UPDATE=""
    _YES="0"
    _PFSENSE_PASSWORD=""
    _PFSENSE_SSH_PASSWORD=""
    while test $# -gt 0; do
        case "$1" in
            -h|--help)
                _help
                exit
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
            --update)
                _UPDATE="1"
                shift
                ;;
            -y|--yes)
                _YES="1"
                shift
                ;;
            --skip-kubespray)
                _SKIP_KUBESPRAY="1"
                shift
                ;;
            --skip-pfsense)
                _SKIP_PFSENSE="1"
                shift
                ;;
            --skip-nodes)
                _SKIP_NODES="1"
                shift
                ;;
            --pfsense-password|--pfsense-password=*)
                case "$1" in
                    *=*)
                        _PFSENSE_PASSWORD="${1#*=}"
                        shift
                        ;;
                    *)
                        _PFSENSE_PASSWORD="$2"
                        shift 2
                        ;;
                esac
                ;;
            --pfsense-ssh-password)
                _PFSENSE_SSH_PASSWORD="1"
                shift
                ;;
            -*)
                _help
                exit 1
                ;;
            *)
                _help
                exit 1
                ;;
        esac
    done
    export ROCK8S_TENANT="$_TENANT"
    export ROCK8S_CLUSTER="$_CLUSTER"
    if [ -z "$ROCK8S_CLUSTER" ]; then
        fail "cluster name required"
    fi
    if [ "$_SKIP_PFSENSE" != "1" ]; then
        sh "$ROCK8S_LIB_PATH/libexec/pfsense/apply.sh" \
            --output="$_OUTPUT" \
            --cluster="$_CLUSTER" \
            --tenant="$_TENANT" \
            $([ "$_UPDATE" = "1" ] && echo "--update") \
            $([ -n "$_PFSENSE_PASSWORD" ] && echo "--password=$_PFSENSE_PASSWORD") \
            $([ "$_PFSENSE_SSH_PASSWORD" = "1" ] && echo "--ssh-password") >/dev/null
    fi
    if [ "$_SKIP_NODES" != "1" ]; then
        sh "$ROCK8S_LIB_PATH/libexec/nodes/apply.sh" \
            --output="$_OUTPUT" \
            --cluster="$_CLUSTER" \
            --tenant="$_TENANT" \
            $([ "$_YES" = "1" ] && echo "--yes") \
            master >/dev/null
        sh "$ROCK8S_LIB_PATH/libexec/nodes/apply.sh" \
            --output="$_OUTPUT" \
            --cluster="$_CLUSTER" \
            --tenant="$_TENANT" \
            $([ "$_YES" = "1" ] && echo "--yes") \
            worker >/dev/null
    fi
    if [ "$_SKIP_PFSENSE" != "1" ]; then
        sh "$ROCK8S_LIB_PATH/libexec/pfsense/publish.sh" \
            --output="$_OUTPUT" \
            --cluster="$_CLUSTER" \
            --tenant="$_TENANT" \
            $([ -n "$_PFSENSE_PASSWORD" ] && echo "--password=$_PFSENSE_PASSWORD") \
            $([ "$_PFSENSE_SSH_PASSWORD" = "1" ] && echo "--ssh-password") >/dev/null
    fi
    if [ "$_SKIP_KUBESPRAY" != "1" ]; then
        sleep 90
        if [ ! -f "$_CLUSTER_DIR/kube.yaml" ]; then
            sh "$ROCK8S_LIB_PATH/libexec/cluster/install.sh" \
                --output="$_OUTPUT" \
                --cluster="$_CLUSTER" \
                --tenant="$_TENANT" \
                $([ "$_UPDATE" = "1" ] && echo "--update") \
                $([ "$_YES" = "1" ] && echo "--yes") \
                $([ -n "$_PFSENSE_PASSWORD" ] && echo "--pfsense-password=$_PFSENSE_PASSWORD") \
                $([ "$_PFSENSE_SSH_PASSWORD" = "1" ] && echo "--pfsense-ssh-password") >/dev/null
        else
            sh "$ROCK8S_LIB_PATH/libexec/cluster/upgrade.sh" \
                --output="$_OUTPUT" \
                --cluster="$_CLUSTER" \
                --tenant="$_TENANT" \
                $([ "$_UPDATE" = "1" ] && echo "--update") \
                $([ "$_YES" = "1" ] && echo "--yes") \
                $([ -n "$_PFSENSE_PASSWORD" ] && echo "--pfsense-password=$_PFSENSE_PASSWORD") \
                $([ "$_PFSENSE_SSH_PASSWORD" = "1" ] && echo "--pfsense-ssh-password") >/dev/null
        fi
    fi
    sh "$ROCK8S_LIB_PATH/libexec/cluster/addons.sh" \
        --output="$_OUTPUT" \
        --cluster="$_CLUSTER" \
        --tenant="$_TENANT" \
        $([ "$_UPDATE" = "1" ] && echo "--update") \
        $([ "$_YES" = "1" ] && echo "--yes") >/dev/null
    printf '{"cluster":"%s","provider":"%s","tenant":"%s"}\n' \
        "$_CLUSTER" "$(get_provider)" "$_TENANT" | \
        format_output "$_OUTPUT"
}

_main "$@"
