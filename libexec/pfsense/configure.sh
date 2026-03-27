#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s pfsense configure

SYNOPSIS
       rock8s pfsense configure [-h] [-o <format>] [--name <name>] [-t <tenant>] [--update] [--password <password>] [--ssh-password]

DESCRIPTION
       configure pfsense

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format

       -t, --tenant <tenant>
              tenant name

       -n, --name <name>
              pfsense instance name

       --update
              update ansible collections

       --password <password>
              admin password

       --ssh-password
              use password authentication for ssh

EXAMPLE
       # configure pfsense
       rock8s pfsense configure --name mypfsense

       # configure pfsense with a specific password
       rock8s pfsense configure --name mypfsense --password mypassword

       # configure pfsense using password authentication for ssh
       rock8s pfsense configure --name mypfsense --ssh-password --password mypassword

SEE ALSO
       rock8s pfsense publish --help
       rock8s pfsense destroy --help
       rock8s cluster install --help
EOF
}

_main() {
    output="${ROCK8S_OUTPUT}"
    tenant="$ROCK8S_TENANT"
    pfsense="$ROCK8S_PFSENSE"
    update=""
    password=""
    ssh_password=0
    while test $# -gt 0; do
        case "$1" in
            -h|--help)
                _help
                exit
                ;;
            -o|--output|-o=*|--output=*)
                case "$1" in
                    *=*)
                        output="${1#*=}"
                        shift
                        ;;
                    *)
                        output="$2"
                        shift 2
                        ;;
                esac
                ;;
            -t|--tenant|-t=*|--tenant=*)
                case "$1" in
                    *=*)
                        tenant="${1#*=}"
                        shift
                        ;;
                    *)
                        tenant="$2"
                        shift 2
                        ;;
                esac
                ;;
            -n|--name|-n=*|--name=*)
                case "$1" in
                    *=*)
                        pfsense="${1#*=}"
                        shift
                        ;;
                    *)
                        pfsense="$2"
                        shift 2
                        ;;
                esac
                ;;
            --password|--password=*)
                case "$1" in
                    *=*)
                        password="${1#*=}"
                        shift
                        ;;
                    *)
                        password="$2"
                        shift 2
                        ;;
                esac
                ;;
            --ssh-password)
                ssh_password=1
                shift
                ;;
            --update)
                update="1"
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
    if [ "$ssh_password" = "1" ]; then
        command -v sshpass >/dev/null 2>&1 || {
            fail "sshpass is not installed"
        }
    fi
    export ROCK8S_PFSENSE="$pfsense"
    export ROCK8S_TENANT="$tenant"
    if [ -z "$ROCK8S_PFSENSE" ]; then
        fail "pfsense name required"
    fi
    pfsense_dir="$(get_pfsense_dir)"
    provider="$(get_provider)"
    mkdir -p "$pfsense_dir"
    pfsense_shared_wan_ipv4="$(get_pfsense_shared_wan_ipv4)"
    pfsense_secondary_hostname="$(get_pfsense_secondary_hostname)"
    if ([ "$ssh_password" = "1" ] || [ -n "$pfsense_secondary_hostname" ]) && [ -z "$password" ]; then
        fail "password required (use --password)"
    fi
    lan_ipv4_subnet="$(get_lan_ipv4_subnet)"
    lan_ipv4_prefix="$(echo "$lan_ipv4_subnet" | cut -d'/' -f2)"
    sync_ipv4_subnet="$(get_sync_ipv4_subnet)"
    sync_ipv4_prefix="$(echo "$sync_ipv4_subnet" | cut -d'/' -f2)"
    rm -rf "$pfsense_dir/ansible"
    cp -r "$ROCK8S_LIB_PATH/pfsense" "$pfsense_dir/ansible"
    mkdir -p "$pfsense_dir/collections"
    ansible-galaxy collection install \
        $([ "$update" = "1" ] && echo "--force") \
        -r "$pfsense_dir/ansible/requirements.yml" \
        -p "$pfsense_dir/collections" >&2
    mkdir -p "$pfsense_dir/collections/ansible_collections/pfsensible"
    defaults="$(yaml2json < "$pfsense_dir/ansible/vars.yml")"
    sync_interface="$(get_sync_interface)"
    pfsense_primary="$(get_pfsense_primary_lan_ipv4)"
    pfsense_secondary="$pfsense_secondary_hostname"
    pfsense_ssh_private_key="$(get_pfsense_ssh_private_key)"
    if ! timeout 5s ssh -i "$pfsense_ssh_private_key" -o StrictHostKeyChecking=no admin@$pfsense_primary 'true' 2>/dev/null; then
        pfsense_primary="$(get_pfsense_primary_hostname)"
        if [ -n "$pfsense_secondary_hostname" ]; then
            pfsense_secondary="$(get_pfsense_secondary_lan_ipv4)"
        fi
    fi
    config="$(cat <<EOF | yaml2json
pfsense:
  provider: $provider
  password: '{{ lookup("env", "PFSENSE_ADMIN_PASSWORD") }}'
  system:
    dns: $(get_dns_servers)
  althostnames: $(get_pfsense_althostnames)
  network:
    interfaces:
      lan:
        subnet: ${lan_ipv4_subnet}
        interface: $(get_lan_interface)
        dhcp: $(get_lan_ipv4_dhcp)
        ipv4:
          primary: $(get_pfsense_primary_lan_ipv4)/${lan_ipv4_prefix}$([ -n "$pfsense_secondary" ] && echo "
          secondary: $(get_pfsense_secondary_lan_ipv4)/${lan_ipv4_prefix}" || true)$([ "$(get_enable_network_dualstack)" = "1" ] && echo "
        ipv6:
          primary: $(get_pfsense_primary_lan_ipv6)/64$([ -n "$pfsense_secondary" ] && echo "
          secondary: $(get_pfsense_secondary_lan_ipv6)/64" || true)" || true)$([ -n "$pfsense_secondary" ] && echo "
        ips:
          - $(get_pfsense_shared_lan_ipv4)/${lan_ipv4_prefix}" || true)$([ -n "$sync_interface" ] && [ -n "$sync_ipv4_subnet" ] && echo "
      sync:
        subnet: $sync_ipv4_subnet
        interface: $sync_interface
        ipv4:
          primary: $(get_pfsense_primary_sync_ipv4)/${sync_ipv4_prefix}
          secondary: $(get_pfsense_secondary_sync_ipv4)/${sync_ipv4_prefix}" || true)$([ -n "$pfsense_shared_wan_ipv4" ] && echo "
      wan:
        ips:
          - \"$pfsense_shared_wan_ipv4\"" || true)
EOF
)"
    echo "$defaults" | jq --argjson config "$config" '. * $config' | json2yaml > "$pfsense_dir/vars.yml"
    cat > "$pfsense_dir/hosts.yml" <<EOF
all:
  vars:
    ansible_user: admin
  hosts:
    pfsense1:
      ansible_host: $pfsense_primary
      primary: true
EOF
    if [ -n "$pfsense_secondary" ]; then
        cat >> "$pfsense_dir/hosts.yml" <<EOF
    pfsense2:
      ansible_host: $pfsense_secondary
      primary: false
EOF
    fi
    if [ -n "$pfsense_ssh_private_key" ] && [ "$ssh_password" = "0" ]; then
        export ANSIBLE_PRIVATE_KEY_FILE="$pfsense_ssh_private_key"
    fi
    cd "$pfsense_dir/ansible"
    ANSIBLE_COLLECTIONS_PATH="$pfsense_dir/collections:/usr/share/ansible/collections" \
        ANSIBLE_HOST_KEY_CHECKING=False \
        PFSENSE_ADMIN_PASSWORD="$password" \
        ansible-playbook \
        -i "$pfsense_dir/hosts.yml" \
        -e "@$pfsense_dir/vars.yml" \
        $([ "$ssh_password" = "1" ] && echo "-e ansible_ssh_pass='$password'") \
        "$pfsense_dir/ansible/playbooks/configure.yml" -v >&2
    printf '{"pfsense":"%s","provider":"%s","tenant":"%s"}\n' \
        "$pfsense" "$(get_provider)" "$tenant" | \
        format_output "$output"
}

_main "$@"
