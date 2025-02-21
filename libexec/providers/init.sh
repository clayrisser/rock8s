#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat << EOF >&2
NAME
       rock8s providers init - initialize provider terraform configuration

SYNOPSIS
       rock8s providers init [-h] [-o <format>] <provider>

DESCRIPTION
       initialize terraform configuration for a cloud provider

ARGUMENTS
       provider
              name of the provider to initialize

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format (default: text)
              supported formats: text, json, yaml
EOF
}

_main() {
    _FORMAT="${ROCK8S_OUTPUT_FORMAT:-text}"
    _PROVIDER=""
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
            -*)
                _help
                exit 1
                ;;
            *)
                if [ -z "$_PROVIDER" ]; then
                    _PROVIDER="$1"
                    shift
                else
                    _help
                    exit 1
                fi
                ;;
        esac
    done

    [ -z "$_PROVIDER" ] && {
        _fail "provider name required"
    }

    _PROVIDER_DIR="$ROCK8S_PROVIDERS_PATH/$_PROVIDER"
    [ -d "$_PROVIDER_DIR" ] || {
        _fail "provider '$_PROVIDER' not found"
    }

    _ensure_terraform

    cd "$_PROVIDER_DIR"
    if [ -f "init.sh" ]; then
        . "./init.sh"
    else
        terraform init
    fi

    printf '{"name":"%s","status":"initialized"}\n' "$_PROVIDER" | _format_output "$_FORMAT" providers
}

_main "$@"
