#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s pfsense destroy

SYNOPSIS
       rock8s pfsense destroy [-h] [-o <format>] [--cluster <cluster>] [-t <tenant>] [-y|--yes] [--force]

DESCRIPTION
       destroy pfsense firewall nodes.

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format

       -t, --tenant <tenant>
              tenant name

       -c, --cluster <cluster>
              cluster name

       -y, --yes
              skip confirmation prompt

       --force
              skip dependency checks

EXAMPLE
       # destroy pfsense firewall with confirmation
       rock8s pfsense destroy --cluster mycluster

       # destroy pfsense firewall without confirmation
       rock8s pfsense destroy --cluster mycluster --yes

       # force destroy pfsense firewall
       rock8s pfsense destroy --cluster mycluster --force --yes

SEE ALSO
       rock8s pfsense configure --help
       rock8s pfsense publish --help
       rock8s nodes destroy --help
EOF
}

_main() {
    _OUTPUT="${ROCK8S_OUTPUT}"
    _TENANT="$ROCK8S_TENANT"
    _CLUSTER="$ROCK8S_CLUSTER"
    _YES=0
    _FORCE=0
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
            -y|--yes)
                _YES=1
                shift
                ;;
            --force)
                _FORCE=1
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
    sh "$ROCK8S_LIB_PATH/libexec/nodes/destroy.sh" \
        --output="$_OUTPUT" \
        --cluster="$_CLUSTER" \
        --tenant="$_TENANT" \
        $([ "$_YES" = "1" ] && echo "--yes") \
        $([ "$_FORCE" = "1" ] && echo "--force") \
        pfsense >/dev/null
    printf '{"cluster":"%s","provider":"%s","tenant":"%s"}\n' \
        "$_CLUSTER" "$(get_provider)" "$_TENANT" | \
        format_output "$_OUTPUT"
}

_main "$@"
