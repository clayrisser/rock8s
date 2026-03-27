#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s pfsense publish

SYNOPSIS
       rock8s pfsense publish [-h] [-o <format>] [--name <name>] [--cluster <cluster>] [-t <tenant>] [--password <password>] [--ssh-password]

DESCRIPTION
       publish cluster haproxy rules to pfsense firewall

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format

       -t, --tenant <tenant>
              tenant name

       -n, --name <name>
              pfsense instance name

       -c, --cluster <cluster>
              cluster name

       --password <password>
              admin password

       --ssh-password
              use password authentication for ssh

EXAMPLE
       # publish cluster rules to pfsense
       rock8s pfsense publish --name mypfsense --cluster mycluster --password mypassword

       # publish with ssh password authentication
       rock8s pfsense publish --name mypfsense --cluster mycluster --password mypassword --ssh-password

SEE ALSO
       rock8s pfsense configure --help
       rock8s cluster addons --help
EOF
}

_main() {
    output="${ROCK8S_OUTPUT}"
    tenant="$ROCK8S_TENANT"
    pfsense="$ROCK8S_PFSENSE"
    cluster="$ROCK8S_CLUSTER"
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
            -c|--cluster|-c=*|--cluster=*)
                case "$1" in
                    *=*)
                        cluster="${1#*=}"
                        shift
                        ;;
                    *)
                        cluster="$2"
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
    export ROCK8S_CLUSTER="$cluster"
    export ROCK8S_TENANT="$tenant"
    if [ -z "$ROCK8S_PFSENSE" ]; then
        fail "pfsense name required"
    fi
    if [ -z "$ROCK8S_CLUSTER" ]; then
        fail "cluster name required"
    fi
    pfsense_dir="$(get_pfsense_dir)"
    if [ "$ssh_password" = "1" ] && [ -z "$password" ]; then
        fail "password required (use --password)"
    fi
    rm -rf "$pfsense_dir/ansible"
    cp -r "$ROCK8S_LIB_PATH/pfsense" "$pfsense_dir/ansible"
    if [ ! -f "$pfsense_dir/vars.yml" ] || [ ! -f "$pfsense_dir/collections/ansible_collections/pfsensible/core/FILES.json" ]; then
        fail "pfsense configure must be run first"
    fi
    lan_ingress_ipv4="$(get_lan_ingress_ipv4)"
    entrypoint_ipv4="$(get_entrypoint_ipv4)"
    entrypoint_ipv6="$(get_entrypoint_ipv6)"
    if [ -n "$lan_ingress_ipv4" ]; then
        ingress_rules="      - \"8080 -> check:${lan_ingress_ipv4}:80\"
      - \"${entrypoint_ipv4}:443 -> check:${lan_ingress_ipv4}:443\"$([ -n "$entrypoint_ipv6" ] && echo "
      - \"[${entrypoint_ipv6}]:443 -> check:${lan_ingress_ipv4}:443\"" || true)"
    else
        http_backend="$(get_haproxy_backend 80 $(get_worker_private_ipv4s))"
        https_backend="$(get_haproxy_backend 443 $(get_worker_private_ipv4s))"
        ingress_rules="      - \"${entrypoint_ipv4}:80 -> ${http_backend}\"
      - \"${entrypoint_ipv4}:443 -> ${https_backend}\"$(
            [ -n "$entrypoint_ipv6" ] && echo "
      - \"[${entrypoint_ipv6}]:80 -> ${http_backend}\"
      - \"[${entrypoint_ipv6}]:443 -> ${https_backend}\"" || true
        )"
    fi
    kube_backend="$(get_haproxy_backend 6443 $(get_master_private_ipv4s))"
    cat > "$pfsense_dir/vars.publish.yml" <<EOF
pfsense:
  provider: $(get_provider)
  network:
    interfaces:
      lan: {}
      wan:
        rules:
          - "allow tcp from any to ${entrypoint_ipv4}"$([ -n "$entrypoint_ipv6" ] && echo "
          - \"allow tcp from any to ${entrypoint_ipv6}\"" || true)
  haproxy:
    rules:
${ingress_rules}
EOF
    if [ -n "$entrypoint_ipv4" ]; then
        echo "      - \"${entrypoint_ipv4}:6443 -> ${kube_backend}\"" >> "$pfsense_dir/vars.publish.yml"
    fi
    if [ -n "$entrypoint_ipv6" ]; then
        echo "      - \"[${entrypoint_ipv6}]:6443 -> ${kube_backend}\"" >> "$pfsense_dir/vars.publish.yml"
    fi
    pfsense_ssh_private_key="$(get_pfsense_ssh_private_key)"
    if [ -n "$pfsense_ssh_private_key" ] && [ "$ssh_password" = "0" ]; then
        export ANSIBLE_PRIVATE_KEY_FILE="$pfsense_ssh_private_key"
    fi
    cd "$pfsense_dir/ansible"
    ANSIBLE_COLLECTIONS_PATH="$pfsense_dir/collections:/usr/share/ansible/collections" \
        ANSIBLE_HOST_KEY_CHECKING=False \
        PFSENSE_ADMIN_PASSWORD="$password" \
        ansible-playbook \
        -i "$pfsense_dir/hosts.yml" \
        -e "@$pfsense_dir/vars.publish.yml" \
        $([ "$ssh_password" = "1" ] && echo "-e ansible_ssh_pass='$password'") \
        "$pfsense_dir/ansible/playbooks/publish.yml" -v >&2
    printf '{"pfsense":"%s","cluster":"%s","provider":"%s","tenant":"%s"}\n' \
        "$pfsense" "$cluster" "$(get_provider)" "$tenant" | \
        format_output "$output"
}

_main "$@"
