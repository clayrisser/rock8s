#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s pfsense configure - configure pfSense

SYNOPSIS
       rock8s pfsense configure [-h] [-o <format>] [--cluster <cluster>] [-t <tenant>] [--update] [--password <password>] [--ssh-password] [--non-interactive] [-y|--yes]

DESCRIPTION
       configure pfsense

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

       --non-interactive
              fail instead of prompting

       -y, --yes
              skip confirmation prompt

EXAMPLE
       # configure pfsense with automatic approval
       rock8s pfsense configure --cluster mycluster --yes

       # configure pfsense with a specific password
       rock8s pfsense configure --cluster mycluster --password mypassword

       # configure pfsense using password authentication for ssh
       rock8s pfsense configure --cluster mycluster --ssh-password --password mypassword

SEE ALSO
       rock8s pfsense publish --help
       rock8s pfsense destroy --help
       rock8s cluster install --help
EOF
}

_main() {
    _FORMAT="${ROCK8S_OUTPUT_FORMAT:-text}"
    _TENANT="$ROCK8S_TENANT"
    _CLUSTER="$ROCK8S_CLUSTER"
    _NON_INTERACTIVE=0
    _UPDATE=""
    _PASSWORD=""
    _SSH_PASSWORD=0
    _YES=0
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
    if [ "$_SSH_PASSWORD" = "1" ]; then
        command -v sshpass >/dev/null 2>&1 || {
            fail "sshpass is not installed"
        }
    fi
    export ROCK8S_CLUSTER="$_CLUSTER"
    export ROCK8S_TENANT="$_TENANT"
    export NON_INTERACTIVE="$_NON_INTERACTIVE"
    _CLUSTER_DIR="$(get_cluster_dir)"
    _PROVIDER="$(get_provider)"
    _PFSENSE_DIR="$_CLUSTER_DIR/pfsense"
    sh "$ROCK8S_LIB_PATH/libexec/nodes/apply.sh" \
        --output="$_FORMAT" \
        --cluster="$_CLUSTER" \
        --tenant="$_TENANT" \
        $([ "$_YES" = "1" ] && echo "--yes") \
        $([ "$NON_INTERACTIVE" = "1" ] && echo "--non-interactive") \
        pfsense
    mkdir -p "$_PFSENSE_DIR"
    _PFSENSE_SHARED_WAN_IPV4="$(get_pfsense_shared_wan_ipv4)"
    _PFSENSE_SECONDARY_HOSTNAME="$(get_pfsense_secondary_hostname)"
    if ([ "$_SSH_PASSWORD" = "1" ] || ([ -n "$_PFSENSE_SECONDARY_HOSTNAME" ])) && [ -z "$_PASSWORD" ] && [ "${NON_INTERACTIVE:-0}" = "0" ]; then
        _PASSWORD="$(whiptail --title "Enter admin password" \
            --backtitle "Rock8s Configuration" \
            --passwordbox " " \
            0 0 \
            3>&1 1>&2 2>&3)" || fail "password required"
    fi
    _LAN_IPV4_SUBNET="$(get_lan_ipv4_subnet)"
    _LAN_IPV4_PREFIX="$(echo "$_LAN_IPV4_SUBNET" | cut -d'/' -f2)"
    _SYNC_IPV4_SUBNET="$(get_sync_ipv4_subnet)"
    _SYNC_IPV4_PREFIX="$(echo "$_SYNC_IPV4_SUBNET" | cut -d'/' -f2)"
    rm -rf "$_PFSENSE_DIR/ansible"
    cp -r "$ROCK8S_LIB_PATH/pfsense" "$_PFSENSE_DIR/ansible"
    mkdir -p "$_PFSENSE_DIR/collections"
    ansible-galaxy collection install \
        $([ "$_UPDATE" = "1" ] && echo "--force") \
        -r "$_PFSENSE_DIR/ansible/requirements.yml" \
        -p "$_PFSENSE_DIR/collections"
    mkdir -p "$_PFSENSE_DIR/collections/ansible_collections/pfsensible"
    _DEFAULTS="$(yaml2json < "$_PFSENSE_DIR/ansible/vars.yml")"
    _SYNC_INTERFACE="$(get_sync_interface)"
    _PFSENSE_PRIMARY="$(get_pfsense_primary_lan_ipv4)"
    _PFSENSE_SECONDARY="$(get_pfsense_secondary_hostname)"
    _PFSENSE_SSH_PRIVATE_KEY="$(get_pfsense_ssh_private_key)"
    if ! timeout 5s ssh -i "$_PFSENSE_SSH_PRIVATE_KEY" -o StrictHostKeyChecking=no admin@$_PFSENSE_PRIMARY 'true' 2>/dev/null; then
        _PFSENSE_PRIMARY="$(get_pfsense_primary_hostname)"
        if [ -n "$_PFSENSE_SECONDARY_HOSTNAME" ]; then
            _PFSENSE_SECONDARY="$(get_pfsense_secondary_lan_ipv4)"
        fi
    fi
    _CONFIG="$(cat <<EOF | yaml2json
pfsense:
  provider: $_PROVIDER
  password: '{{ lookup("env", "PFSENSE_ADMIN_PASSWORD") }}'
  system:
    dns: $(get_dns_servers)
  althostnames: $(get_pfsense_althostnames)
  network:
    interfaces:
      lan:
        subnet: ${_LAN_IPV4_SUBNET}
        interface: $(get_lan_interface)
        dhcp: $(get_lan_ipv4_dhcp)
        ipv4:
          primary: $(get_pfsense_primary_lan_ipv4)/${_LAN_IPV4_PREFIX}
          secondary: $(get_pfsense_secondary_lan_ipv4)/${_LAN_IPV4_PREFIX}
        ipv6:
          primary: $(get_pfsense_primary_lan_ipv6)/64
          secondary: $(get_pfsense_secondary_lan_ipv6)/64
        ips:
          - $(get_pfsense_shared_lan_ipv4)/${_LAN_IPV4_PREFIX}$([ -n "$_SYNC_INTERFACE" ] && [ -n "$_SYNC_IPV4_SUBNET" ] && echo "
      sync:
        subnet: $_SYNC_IPV4_SUBNET
        interface: $_SYNC_INTERFACE
        ipv4:
          primary: $(get_pfsense_primary_sync_ipv4)/${_SYNC_IPV4_PREFIX}
          secondary: $(get_pfsense_secondary_sync_ipv4)/${_SYNC_IPV4_PREFIX}")$([ -n "$_PFSENSE_SHARED_WAN_IPV4" ] && echo "
      wan:
        ips:
          - \"$_PFSENSE_SHARED_WAN_IPV4\"")
EOF
)"
    echo "$_DEFAULTS" | jq --argjson config "$_CONFIG" '. * $config' | json2yaml > "$_PFSENSE_DIR/vars.yml"
    cat > "$_PFSENSE_DIR/hosts.yml" <<EOF
all:
  vars:
    ansible_user: admin
  hosts:
    pfsense1:
      ansible_host: $_PFSENSE_PRIMARY
      primary: true
EOF
    if [ -n "$_PFSENSE_SECONDARY" ]; then
        cat >> "$_PFSENSE_DIR/hosts.yml" <<EOF
    pfsense2:
      ansible_host: $_PFSENSE_SECONDARY
      primary: false
EOF
    fi
    if [ -n "$_PFSENSE_SSH_PRIVATE_KEY" ] && [ "$_SSH_PASSWORD" = "0" ]; then
        export ANSIBLE_PRIVATE_KEY_FILE="$_PFSENSE_SSH_PRIVATE_KEY"
    fi
    cd "$_PFSENSE_DIR/ansible"
    ANSIBLE_COLLECTIONS_PATH="$_PFSENSE_DIR/collections:/usr/share/ansible/collections" \
        ANSIBLE_HOST_KEY_CHECKING=False \
        PFSENSE_ADMIN_PASSWORD="$_PASSWORD" \
        ansible-playbook \
        -i "$_PFSENSE_DIR/hosts.yml" \
        -e "@$_PFSENSE_DIR/vars.yml" \
        $([ "$_SSH_PASSWORD" = "1" ] && echo "-e ansible_ssh_pass='$_PASSWORD'") \
        "$_PFSENSE_DIR/ansible/playbooks/configure.yml" -v
    printf '{"name":"%s"}\n' "$_CLUSTER" | format_output "$_FORMAT"
}

_main "$@"
