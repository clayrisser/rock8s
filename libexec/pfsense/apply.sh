#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s pfsense apply

SYNOPSIS
       rock8s pfsense apply [-h] [-o <format>] [--cluster <cluster>] [-t <tenant>] [--update] [--password <password>] [--ssh-password] [-y|--yes]

DESCRIPTION
       create and configure pfsense

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

       --password <password>
              admin password

       --ssh-password
              use password authentication for ssh

       -y, --yes
              skip confirmation prompt

EXAMPLE
       # apply pfsense with automatic approval
       rock8s pfsense apply --cluster mycluster --yes

       # apply pfsense with a specific password
       rock8s pfsense apply --cluster mycluster --password mypassword

       # apply pfsense using password authentication for ssh
       rock8s pfsense apply --cluster mycluster --ssh-password --password mypassword

SEE ALSO
       rock8s pfsense configure --help
       rock8s pfsense destroy --help
       rock8s cluster install --help
EOF
}

_main() {
    _OUTPUT="${ROCK8S_OUTPUT}"
    _TENANT="$ROCK8S_TENANT"
    _CLUSTER="$ROCK8S_CLUSTER"
    _UPDATE=""
    _PASSWORD=""
    _SSH_PASSWORD=0
    _YES=0
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
            --password|--password=*)
                case "$1" in
                    *=*)
                        _PASSWORD="${1#*=}"
                        shift
                        ;;
                    *)
                        _PASSWORD="$2"
                        shift 2
                        ;;
                esac
                ;;
            --ssh-password)
                _SSH_PASSWORD=1
                shift
                ;;
            --update)
                _UPDATE="1"
                shift
                ;;
            -y|--yes)
                _YES=1
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
    if [ -z "$ROCK8S_CLUSTER" ]; then
        fail "cluster name required"
    fi
    sh "$ROCK8S_LIB_PATH/libexec/nodes/apply.sh" \
        --output="$_OUTPUT" \
        --cluster="$_CLUSTER" \
        --tenant="$_TENANT" \
        $([ "$_YES" = "1" ] && echo "--yes") \
        pfsense >/dev/null
    sh "$ROCK8S_LIB_PATH/libexec/pfsense/configure.sh" \
        --output="$_OUTPUT" \
        --cluster="$_CLUSTER" \
        --tenant="$_TENANT" \
        $([ "$_UPDATE" = "1" ] && echo "--update") \
        $([ -n "$_PASSWORD" ] && echo "--password '$_PASSWORD'") \
        $([ "$_SSH_PASSWORD" = "1" ] && echo "--ssh-password") >/dev/null
    printf '{"cluster":"%s","provider":"%s","tenant":"%s"}\n' \
        "$_CLUSTER" "$(get_provider)" "$_TENANT" | \
        format_output "$_OUTPUT"
}

_main "$@"
