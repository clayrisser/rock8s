#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat << EOF >&2
NAME
       rock8s providers list - list available providers

SYNOPSIS
       rock8s providers list [-h] [-o <format>]

DESCRIPTION
       list available cloud providers for node provisioning

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format (default: text)
              supported formats: text, json, yaml

SUPPORTED PROVIDERS
       aws         Amazon Web Services
       gcp         Google Cloud Platform
       azure       Microsoft Azure
       digitalocean DigitalOcean
       openstack   OpenStack
       vsphere     VMware vSphere
       custom      Custom provider (bring your own Terraform)
EOF
}

_main() {
    _FORMAT="${ROCK8S_OUTPUT_FORMAT:-text}"
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
            *)
                _help
                exit 1
                ;;
        esac
    done

    _PROVIDERS=""
    for _PROVIDER in "$ROCK8S_PROVIDERS_PATH"/*; do
        [ -d "$_PROVIDER" ] || continue
        _NAME="$(basename "$_PROVIDER")"
        _DESC=""
        [ -f "$_PROVIDER/description.txt" ] && _DESC="$(head -n1 "$_PROVIDER/description.txt")"
        _PROVIDERS="$_PROVIDERS{\"name\":\"$_NAME\",\"description\":\"$_DESC\"},"
    done
    [ -n "$_PROVIDERS" ] && _PROVIDERS="[${_PROVIDERS%,}]" || _PROVIDERS="[]"
    printf "%s\n" "$_PROVIDERS" | _format_output "$_FORMAT" providers
}

_main "$@"
