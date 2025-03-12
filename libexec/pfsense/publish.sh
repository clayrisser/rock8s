#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s pfsense publish - publish HAProxy configuration

SYNOPSIS
       rock8s pfsense publish [-h] [-o <format>] [--cluster <cluster>] [-t <tenant>] [--password <password>] [--ssh-password]

DESCRIPTION
       publish HAProxy configuration to pfSense firewall for load balancing

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format (default: text)
              supported formats: text, json, yaml

       -t, --tenant <tenant>
              tenant name (default: current user)

       --cluster <cluster>
              name of the cluster to configure pfSense for (required)

       --password <password>
              admin password

       --ssh-password
              use password authentication for ssh instead of an ssh key
EOF
}

_main() {
    _FORMAT="${ROCK8S_OUTPUT_FORMAT:-text}"
    _TENANT="$ROCK8S_TENANT"
    _CLUSTER="$ROCK8S_CLUSTER"
    _NON_INTERACTIVE=0
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
            _fail "sshpass is not installed"
        }
    fi
    export ROCK8S_CLUSTER="$_CLUSTER"
    export NON_INTERACTIVE="$_NON_INTERACTIVE"
    _PFSENSE_DIR="$(_get_cluster_dir)/pfsense"
    rm -rf "$_PFSENSE_DIR/ansible"
    cp -r "$ROCK8S_LIB_PATH/pfsense" "$_PFSENSE_DIR/ansible"
    if [ ! -f "$_PFSENSE_DIR/vars.yml" ] || [ ! -f "$_PFSENSE_DIR/collections/ansible_collections/pfsensible/core/FILES.json" ]; then
        _fail "pfsense configure must be run first"
    fi
    _LAN_INGRESS_IPV4="$(_get_lan_ingress_ipv4)"
    _ENTRYPOINT_IP="$(_get_entrypoint_ip)"
    if [ -n "$_LAN_INGRESS_IPV4" ]; then
        _INGRESS_RULES="      - \"8080 -> check:${_LAN_INGRESS_IPV4}:80\"
      - \"${_ENTRYPOINT_IP}:443 -> check:${_LAN_INGRESS_IPV4}:443\""
    else
        _HTTP_BACKEND="$(_get_haproxy_backend 80 $(_get_worker_private_ipv4s))"
        _HTTPS_BACKEND="$(_get_haproxy_backend 443 $(_get_worker_private_ipv4s))"
        _INGRESS_RULES="      - \"${_ENTRYPOINT_IP}:80 -> ${_HTTP_BACKEND}\"
      - \"${_ENTRYPOINT_IP}:443 -> ${_HTTPS_BACKEND}\""
    fi
    _KUBE_BACKEND="$(_get_haproxy_backend 6443 $(_get_master_private_ipv4s))"
    cat > "$_PFSENSE_DIR/vars.publish.yml" <<EOF
pfsense:
  provider: $(_get_provider)
  network:
    interfaces:
      wan:
        rules:
          - allow tcp from any to ${_ENTRYPOINT_IP}
  haproxy:
    rules:
${_INGRESS_RULES}
EOF
    if [ -n "$_ENTRYPOINT_IP" ]; then
        echo "      - \"${_ENTRYPOINT_IP}:6443 -> ${_KUBE_BACKEND}\"" >> "$_PFSENSE_DIR/vars.publish.yml"
    fi
    _PFSENSE_SSH_PRIVATE_KEY="$(_get_pfsense_ssh_private_key)"
    if [ -n "$_PFSENSE_SSH_PRIVATE_KEY" ] && [ "$_PFSENSE_SSH_PRIVATE_KEY" != "null" ] && [ "$_SSH_PASSWORD" = "0" ]; then
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
        "$_PFSENSE_DIR/ansible/playbooks/publish.yml" -v
    printf '{"name":"%s"}\n' "$_CLUSTER" | _format_output "$_FORMAT"
}

_main "$@"
