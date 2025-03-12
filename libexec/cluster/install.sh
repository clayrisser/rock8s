#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s cluster install - install kubernetes cluster

SYNOPSIS
       rock8s cluster install [-h] [-o <format>] [--cluster <cluster>] [-t <tenant>] [--update] [-y|--yes] [--non-interactive]

DESCRIPTION
       install kubernetes cluster using kubespray

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format (default: text)
              supported formats: text, json, yaml

       -t, --tenant <tenant>
              tenant name (default: current user)

       --cluster <cluster>
              name of the cluster to install kubernetes on (required)

       --update
              update ansible collections

       -y, --yes
              skip confirmation prompt

       --non-interactive
              fail instead of prompting for missing values

       --pfsense-password <password>
              admin password

       --pfsense-ssh-password
              use password authentication for ssh instead of an ssh key
EOF
}

_main() {
    _FORMAT="${ROCK8S_OUTPUT_FORMAT:-text}"
    _CLUSTER="$ROCK8S_CLUSTER"
    _TENANT="$ROCK8S_TENANT"
    _UPDATE=""
    _YES=""
    _NON_INTERACTIVE=""
    _PFSENSE_PASSWORD=""
    _PFSENSE_SSH_PASSWORD=""
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
            --update)
                _UPDATE="1"
                shift
                ;;
            -y|--yes)
                _YES="1"
                shift
                ;;
            -n|--non-interactive)
                _NON_INTERACTIVE="1"
                shift
                ;;
            --pfsense-password|--pfsense-password=*)
                case "$1" in
                    *=*)
                        _PFSENSE_PASSWORD="${1#*=}"
                        shift
                        ;;
                    *)
                        _PFSENSE_PASSWORD="$2"
                        shift 2
                        ;;
                esac
                ;;
            --pfsense-ssh-password|--pfsense-ssh-password=*)
                case "$1" in
                    *=*)
                        _PFSENSE_SSH_PASSWORD="${1#*=}"
                        shift
                        ;;
                    *)
                        _PFSENSE_SSH_PASSWORD="$2"
                        shift 2
                        ;;
                esac
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
    if [ -z "$_CLUSTER" ]; then
        _fail "cluster name required"
    fi
    export ROCK8S_CLUSTER="$_CLUSTER"
    export ROCK8S_TENANT="$_TENANT"
    export NON_INTERACTIVE="$_NON_INTERACTIVE"
    sh "$ROCK8S_LIB_PATH/libexec/nodes/apply.sh" \
        --output="$_FORMAT" \
        --cluster="$_CLUSTER" \
        --tenant="$_TENANT" \
        $([ "$_UPDATE" = "1" ] && echo "--update") \
        $([ "$_YES" = "1" ] && echo "--yes") \
        $([ "$_NON_INTERACTIVE" = "1" ] && echo "--non-interactive") \
        master
    sh "$ROCK8S_LIB_PATH/libexec/nodes/apply.sh" \
        --output="$_FORMAT" \
        --cluster="$_CLUSTER" \
        --tenant="$_TENANT" \
        $([ "$_UPDATE" = "1" ] && echo "--update") \
        $([ "$_YES" = "1" ] && echo "--yes") \
        $([ "$_NON_INTERACTIVE" = "1" ] && echo "--non-interactive") \
        worker
    _KUBESPRAY_DIR="$(_get_kubespray_dir)"
    if [ ! -d "$_KUBESPRAY_DIR" ]; then
        git clone --depth 1 --branch "$KUBESPRAY_VERSION" "$KUBESPRAY_REPO" "$_KUBESPRAY_DIR"
    fi
    _VENV_DIR="$_KUBESPRAY_DIR/venv"
    if [ ! -d "$_VENV_DIR" ]; then
        python3 -m venv "$_VENV_DIR"
    fi
    . "$_VENV_DIR/bin/activate"
    if command -v uv >/dev/null 2>&1; then
        uv pip install -r "$_KUBESPRAY_DIR/requirements.txt"
    else
        pip install -r "$_KUBESPRAY_DIR/requirements.txt"
    fi
    _INVENTORY_DIR="$(_get_inventory_dir)"
    if [ ! -d "$_INVENTORY_DIR" ]; then
        cp -r "$_KUBESPRAY_DIR/inventory/sample" "$_INVENTORY_DIR"
    fi
    cp "$ROCK8S_LIB_PATH/kubespray/vars.yml" "$_INVENTORY_DIR/vars.yml"
    _MTU="$(_get_network_mtu)"
    cp "$ROCK8S_LIB_PATH/kubespray/postinstall.yml" "$_KUBESPRAY_DIR/postinstall.yml"
    _LAN_METALLB="$(_get_lan_metallb)"
    cat >> "$_INVENTORY_DIR/vars.yml" <<EOF
metallb_enabled: $([ -n "$_LAN_METALLB" ] && echo "true" || echo "false")
kube_proxy_strict_arp: $([ -n "$_LAN_METALLB" ] && echo "true" || echo "false")
enable_dual_stack_networks: $(_get_network_dualstack)
supplementary_addresses_in_ssl_keys: [$(_get_supplementary_addresses)]
calico_mtu: $_MTU
calico_veth_mtu: $(($_MTU - 50))
metallb: "$_LAN_METALLB"
EOF
    _MASTER_ANSIBLE_PRIVATE_HOSTS="$(_get_master_ansible_private_hosts)"
    _MASTER_SSH_PRIVATE_KEY="$(_get_master_ssh_private_key)"
    _WORKER_ANSIBLE_PRIVATE_HOSTS="$(_get_worker_ansible_private_hosts)"
    _WORKER_SSH_PRIVATE_KEY="$(_get_worker_ssh_private_key)"
    cat > "$_INVENTORY_DIR/inventory.ini" <<EOF
[kube_control_plane]
$(echo "$_MASTER_ANSIBLE_PRIVATE_HOSTS" | sed "s|\(.*\)|\1 ansible_ssh_private_key_file=$_MASTER_SSH_PRIVATE_KEY|g")

[etcd]
$(echo "$_MASTER_ANSIBLE_PRIVATE_HOSTS" | sed "s|\(.*\)|\1 ansible_ssh_private_key_file=$_MASTER_SSH_PRIVATE_KEY|g")

[kube_node]
$(echo "$_WORKER_ANSIBLE_PRIVATE_HOSTS" | sed "s|\(.*\)|\1 ansible_ssh_private_key_file=$_WORKER_SSH_PRIVATE_KEY|g")

[k8s-cluster:children]
kube_node
kube_control_plane

[kube_control_plane:vars]
node_labels={"topology.kubernetes.io/zone": "$ROCK8S_CLUSTER"}

[kube_node:vars]
node_labels={"topology.kubernetes.io/zone": "$ROCK8S_CLUSTER"}
EOF
    ANSIBLE_ROLES_PATH="$_KUBESPRAY_DIR/roles" \
        ANSIBLE_HOST_KEY_CHECKING=False \
        "$_KUBESPRAY_DIR/venv/bin/ansible-playbook" \
        -i "$_INVENTORY_DIR/inventory.ini" \
        -e "@$_INVENTORY_DIR/vars.yml" \
        -u admin --become --become-user=root \
        "$_KUBESPRAY_DIR/cluster.yml" -b -v
    ANSIBLE_ROLES_PATH="$_KUBESPRAY_DIR/roles" \
        ANSIBLE_HOST_KEY_CHECKING=False \
        "$_KUBESPRAY_DIR/venv/bin/ansible-playbook" \
        -i "$_INVENTORY_DIR/inventory.ini" \
        -e "@$_INVENTORY_DIR/vars.yml" \
        -u admin --become --become-user=root \
        "$_KUBESPRAY_DIR/postinstall.yml" -b -v
    "$ROCK8S_LIB_PATH/libexec/cluster/login.sh" \
        --output="$_FORMAT" \
        --cluster="$_CLUSTER" \
        --tenant="$_TENANT" \
        --kubeconfig "$(_get_cluster_dir)/kube.yaml"
    sh "$ROCK8S_LIB_PATH/libexec/pfsense/publish.sh" \
        --output="$_FORMAT" \
        --cluster="$_CLUSTER" \
        --tenant="$_TENANT" \
        $([ "$_NON_INTERACTIVE" = "1" ] && echo "--non-interactive") \
        $([ -n "$_PFSENSE_PASSWORD" ] && echo "--password=$_PFSENSE_PASSWORD") \
        $([ -n "$_PFSENSE_SSH_PASSWORD" ] && echo "--ssh-password=$_PFSENSE_SSH_PASSWORD")
    printf '{"name":"%s"}\n' "$_CLUSTER" | _format_output "$_FORMAT" cluster
}

_main "$@"
