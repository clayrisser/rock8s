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
    _CLUSTER_DIR="$(_get_cluster_dir)"
    _PROVIDER="$(_get_provider)"
    _PFSENSE_DIR="$_CLUSTER_DIR/pfsense"
    _PFSENSE_PRIMARY_LAN_IPV4="$(_get_pfsense_primary_lan_ipv4)"
    _PFSENSE_SECONDARY_LAN_IPV4="$(_get_pfsense_secondary_lan_ipv4)"
    _MASTER_OUTPUT_JSON="$(_get_node_output_file "$_CLUSTER_DIR" "master")"
    _MASTER_IPS="$(_get_node_master_ips "$_MASTER_OUTPUT_JSON")"
    if [ -z "$_PASSWORD" ] && [ "${NON_INTERACTIVE:-0}" = "0" ]; then
        _PASSWORD="$(whiptail --title "Enter admin password" \
            --backtitle "Rock8s Configuration" \
            --passwordbox " " \
            0 0 \
            3>&1 1>&2 2>&3)" || _fail "password required"
    fi
    rm -rf "$_PFSENSE_DIR/ansible"
    cp -r "$ROCK8S_LIB_PATH/pfsense" "$_PFSENSE_DIR/ansible"
    cat > "$_PFSENSE_DIR/hosts.yml" <<EOF
all:
  vars:
    ansible_user: admin
  hosts:
    pfsense1:
      ansible_host: $_PFSENSE_PRIMARY_LAN_IPV4
      primary: true
EOF
    if [ -n "$_PFSENSE_SECONDARY_LAN_IPV4" ] && [ "$_PFSENSE_SECONDARY_LAN_IPV4" != "null" ]; then
        cat >> "$_PFSENSE_DIR/hosts.yml" <<EOF
    pfsense2:
      ansible_host: $_PFSENSE_SECONDARY_LAN_IPV4
      primary: false
EOF
    fi
    cat > "$_PFSENSE_DIR/vars.yml" <<EOF
pfsense:
  provider: $_PROVIDER
  password: '{{ lookup("env", "PFSENSE_ADMIN_PASSWORD") }}'
  haproxy:
    enabled: true
    frontends:
      - name: k8s_api
        bind: "*:6443"
        mode: tcp
        backends:
          - name: k8s_api_backend
            mode: tcp
            balance: roundrobin
            servers: $_MASTER_IPS
    backends:
      - name: k8s_api_backend
        mode: tcp
        balance: roundrobin
        servers: $_MASTER_IPS
EOF
    cd "$_PFSENSE_DIR/ansible"
    echo ANSIBLE_COLLECTIONS_PATH="$_PFSENSE_DIR/collections:/usr/share/ansible/collections" \
        PFSENSE_ADMIN_PASSWORD="$_PASSWORD" \
        ansible-playbook -v -i "$_PFSENSE_DIR/hosts.yml" \
        -e "@$_PFSENSE_DIR/vars.yml" \
        $([ "$_SSH_PASSWORD" = "1" ] && echo "-e ansible_ssh_pass='$_PASSWORD'") \
        "$_PFSENSE_DIR/ansible/playbooks/haproxy.yml"
    
    printf '{"name":"%s"}\n' "$_CLUSTER" | _format_output "$_FORMAT"
}

_main "$@"
