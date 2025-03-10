#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s pfsense destroy - destroy pfSense firewall

SYNOPSIS
       rock8s pfsense destroy [-h] [-o <format>] [--cluster <cluster>] [-t <tenant>] [-y|--yes] [--force] [--non-interactive]

DESCRIPTION
       destroy pfSense firewall nodes

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format (default: text)
              supported formats: text, json, yaml

       -t, --tenant <tenant>
              tenant name (default: current user)

       --cluster <cluster>
              name of the cluster to destroy pfSense for (required)

       -y, --yes
              skip confirmation prompt

       --force
              skip dependency checks for destruction order

       --non-interactive
              fail instead of prompting for missing values
EOF
}

_main() {
    _FORMAT="${ROCK8S_OUTPUT_FORMAT:-text}"
    _TENANT="$ROCK8S_TENANT"
    _CLUSTER="$ROCK8S_CLUSTER"
    _YES=0
    _FORCE=0
    _NON_INTERACTIVE=0
    while test $# -gt 0; do
        case "$1" in
            -h|--help)
                _help
                exit 0
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
            -y|--yes)
                _YES=1
                shift
                ;;
            --force)
                _FORCE=1
                shift
                ;;
            --non-interactive)
                _NON_INTERACTIVE=1
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
    export ROCK8S_CLUSTER="$_CLUSTER"
    export ROCK8S_TENANT="$_TENANT"
    export NON_INTERACTIVE="$_NON_INTERACTIVE"
    sh "$ROCK8S_LIB_PATH/libexec/nodes/destroy.sh" \
        --output="$_FORMAT" \
        --cluster="$_CLUSTER" \
        --tenant="$_TENANT" \
        $([ "$_YES" = "1" ] && echo "--yes") \
        $([ "$_FORCE" = "1" ] && echo "--force") \
        $([ "$_NON_INTERACTIVE" = "1" ] && echo "--non-interactive") \
        pfsense
}

_main "$@"
