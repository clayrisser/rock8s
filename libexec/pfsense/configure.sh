#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat << EOF >&2
NAME
       rock8s pfsense configure - configure pfSense

SYNOPSIS
       rock8s pfsense configure [-h] [-o <format>] <n>

DESCRIPTION
       configure pfSense settings including network interfaces, firewall rules, and system settings

ARGUMENTS
       name
              name of the cluster to configure pfSense for

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
    _NAME=""
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
                if [ -z "$_NAME" ]; then
                    _NAME="$1"
                    shift
                else
                    _help
                    exit 1
                fi
                ;;
        esac
    done
    [ -z "$_NAME" ] && {
        _fail "cluster name required"
    }
    _CLUSTER_DIR="$(_get_cluster_dir "$_NAME")"
    _PFSENSE_DIR="$_CLUSTER_DIR/pfsense"
    mkdir -p "$_PFSENSE_DIR"
    cp -r "$ROCK8S_LIB_PATH/pfsense" "$_PFSENSE_DIR/ansible"
    _log "Initializing Python virtual environment..."
    python3 -m venv "$_PFSENSE_DIR/venv"
    . "$_PFSENSE_DIR/venv/bin/activate"
    _log "Installing Ansible requirements..."
    ansible-galaxy collection install -r "$_PFSENSE_DIR/ansible/requirements.yml"
    _log "Generating inventory..."
    cat > "$_PFSENSE_DIR/ansible/inventory/hosts.yml" << EOF
all:
  children:
    primary:
      hosts:
$(jq -r '.node_ips.value | to_entries | .[] | select(.key | endswith("pfsense1")) | "        \(.key):\n          ansible_host: \(.value)\n          ansible_user: root\n          ansible_python_interpreter: /usr/local/bin/python3.11\n          primary: true"' "$_CLUSTER_DIR/output.json")
    secondary:
      hosts:
$(jq -r '.node_ips.value | to_entries | .[] | select(.key | endswith("pfsense2")) | "        \(.key):\n          ansible_host: \(.value)\n          ansible_user: root\n          ansible_python_interpreter: /usr/local/bin/python3.11\n          primary: false"' "$_CLUSTER_DIR/output.json")
  vars:
    ansible_ssh_private_key_file: $(jq -r '.node_ssh_private_key.value' "$_CLUSTER_DIR/output.json")
EOF
    cat > "$_PFSENSE_DIR/ansible/vars/cluster.yml" << EOF
---
pfsense: {}
EOF
    _log "Running configuration playbook..."
    ANSIBLE_CONFIG="$_PFSENSE_DIR/ansible/ansible.cfg" \
    export ANSIBLE_PRIVATE_KEY_FILE="$(jq -r '.node_ssh_private_key.value' "$_CLUSTER_DIR/output.json")"
    ansible-playbook -i "$_PFSENSE_DIR/ansible/inventory/hosts.yml" \
        "$_PFSENSE_DIR/ansible/playbooks/configure.yml" \
        -e "@$_PFSENSE_DIR/ansible/vars/cluster.yml" \
        -e "@$_PFSENSE_DIR/ansible/roles/pfsense/defaults/main.yml" \
        -v "$@"

    printf '{"name":"%s","status":"configured"}\n' "$_NAME" | _format_output "$_FORMAT" pfsense
}

_main "$@"
