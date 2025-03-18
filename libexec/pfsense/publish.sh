#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s pfsense publish

SYNOPSIS
       rock8s pfsense publish [-h] [-o <format>] [--cluster <cluster>] [-t <tenant>] [--password <password>] [--ssh-password]

DESCRIPTION
       publish cluster configuration to pfsense firewall

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format

       -t, --tenant <tenant>
              tenant name

       -c, --cluster <cluster>
              cluster name

       --password <password>
              admin password

       --ssh-password
              use password authentication for ssh

EXAMPLE
       # publish configuration with a password
       rock8s pfsense publish --cluster mycluster --password mypassword

       # publish configuration with ssh password authentication
       rock8s pfsense publish --cluster mycluster --password mypassword --ssh-password

SEE ALSO
       rock8s pfsense configure --help
       rock8s cluster configure --help
EOF
}

_main() {
    _OUTPUT="${ROCK8S_OUTPUT}"
    _TENANT="$ROCK8S_TENANT"
    _CLUSTER="$ROCK8S_CLUSTER"
    _PASSWORD=""
    _SSH_PASSWORD=0
    while test $# -gt 0; do
        case "$1" in
            -h|--help)
                _help
                exit 0
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
    if [ "$_SSH_PASSWORD" = "1" ]; then
        command -v sshpass >/dev/null 2>&1 || {
            fail "sshpass is not installed"
        }
    fi
    export ROCK8S_CLUSTER="$_CLUSTER"
    _PFSENSE_DIR="$(get_cluster_dir)/pfsense"
    if [ "$_SSH_PASSWORD" = "1" ] && [ -z "$_PASSWORD" ]; then
        _PASSWORD="$(whiptail --title "Enter admin password" \
            --backtitle "Rock8s Configuration" \
            --passwordbox " " \
            0 0 \
            3>&1 1>&2 2>&3)" || fail "password required"
    fi
    rm -rf "$_PFSENSE_DIR/ansible"
    cp -r "$ROCK8S_LIB_PATH/pfsense" "$_PFSENSE_DIR/ansible"
    if [ ! -f "$_PFSENSE_DIR/vars.yml" ] || [ ! -f "$_PFSENSE_DIR/collections/ansible_collections/pfsensible/core/FILES.json" ]; then
        fail "pfsense configure must be run first"
    fi
    _LAN_INGRESS_IPV4="$(get_lan_ingress_ipv4)"
    _ENTRYPOINT_IPV4="$(get_entrypoint_ipv4)"
    _ENTRYPOINT_IPV6="$(get_entrypoint_ipv6)"
    if [ -n "$_LAN_INGRESS_IPV4" ]; then
        _INGRESS_RULES="      - \"8080 -> check:${_LAN_INGRESS_IPV4}:80\"
      - \"${_ENTRYPOINT_IPV4}:443 -> check:${_LAN_INGRESS_IPV4}:443\"$([ -n "$_ENTRYPOINT_IPV6" ] && echo "
      - \"[${_ENTRYPOINT_IPV6}]:443 -> check:${_LAN_INGRESS_IPV4}:443\"" || true)"
    else
        _HTTP_BACKEND="$(get_haproxy_backend 80 $(get_worker_private_ipv4s))"
        _HTTPS_BACKEND="$(get_haproxy_backend 443 $(get_worker_private_ipv4s))"
        _INGRESS_RULES="      - \"${_ENTRYPOINT_IPV4}:80 -> ${_HTTP_BACKEND}\"
      - \"${_ENTRYPOINT_IPV4}:443 -> ${_HTTPS_BACKEND}\"$(
            [ -n "$_ENTRYPOINT_IPV6" ] && echo "
      - \"[${_ENTRYPOINT_IPV6}]:80 -> ${_HTTP_BACKEND}\"
      - \"[${_ENTRYPOINT_IPV6}]:443 -> ${_HTTPS_BACKEND}\"" || true
        )"
    fi
    _KUBE_BACKEND="$(get_haproxy_backend 6443 $(get_master_private_ipv4s))"
    cat > "$_PFSENSE_DIR/vars.publish.yml" <<EOF
pfsense:
  provider: $(get_provider)
  network:
    interfaces:
      wan:
        rules:
          - "allow tcp from any to ${_ENTRYPOINT_IPV4}"$([ -n "$_ENTRYPOINT_IPV6" ] && echo "
          - \"allow tcp from any to ${_ENTRYPOINT_IPV6}\"
          - \"allow tcp from ${_ENTRYPOINT_IPV6} to ${_ENTRYPOINT_IPV4}\"
          - \"allow tcp from [${_ENTRYPOINT_IPV6}] to [${_ENTRYPOINT_IPV6}]\"" || true)
  haproxy:
    rules:
${_INGRESS_RULES}
EOF
    if [ -n "$_ENTRYPOINT_IPV4" ]; then
        echo "      - \"${_ENTRYPOINT_IPV4}:6443 -> ${_KUBE_BACKEND}\"" >> "$_PFSENSE_DIR/vars.publish.yml"
    fi
    if [ -n "$_ENTRYPOINT_IPV6" ]; then
        echo "      - \"[${_ENTRYPOINT_IPV6}]:6443 -> ${_KUBE_BACKEND}\"" >> "$_PFSENSE_DIR/vars.publish.yml"
    fi
    _PFSENSE_SSH_PRIVATE_KEY="$(get_pfsense_ssh_private_key)"
    if [ -n "$_PFSENSE_SSH_PRIVATE_KEY" ] && [ "$_SSH_PASSWORD" = "0" ]; then
        export ANSIBLE_PRIVATE_KEY_FILE="$_PFSENSE_SSH_PRIVATE_KEY"
    fi
    cd "$_PFSENSE_DIR/ansible"
    ANSIBLE_COLLECTIONS_PATH="$_PFSENSE_DIR/collections:/usr/share/ansible/collections" \
        ANSIBLE_HOST_KEY_CHECKING=False \
        PFSENSE_ADMIN_PASSWORD="$_PASSWORD" \
        ansible-playbook \
        -i "$_PFSENSE_DIR/hosts.yml" \
        -e "@$_PFSENSE_DIR/vars.publish.yml" \
        $([ "$_SSH_PASSWORD" = "1" ] && echo "-e ansible_ssh_pass='$_PASSWORD'") \
        "$_PFSENSE_DIR/ansible/playbooks/publish.yml" -v >&2
    printf '{"name":"%s"}\n' "$_CLUSTER" | format_output "$_OUTPUT"
}

_main "$@"
