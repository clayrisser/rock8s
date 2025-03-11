#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s cluster upgrade - upgrade kubernetes cluster

SYNOPSIS
       rock8s cluster upgrade [-h] [-o <format>] [--cluster <cluster>] [-t <tenant>]

DESCRIPTION
       upgrade an existing kubernetes cluster using kubespray

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format (default: text)
              supported formats: text, json, yaml

       -t, --tenant <tenant>
              tenant name (default: current user)

       --cluster <cluster>
              name of the cluster to upgrade (required)
EOF
}

_main() {
    _FORMAT="${ROCK8S_OUTPUT_FORMAT:-text}"
    _CLUSTER="$ROCK8S_CLUSTER"
    _TENANT="$ROCK8S_TENANT"
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
    _CLUSTER_DIR="$(_get_cluster_dir)"
    _MASTER_OUTPUT="$_CLUSTER_DIR/master/output.json"
    if [ ! -f "$_MASTER_OUTPUT" ]; then
        _fail "master output.json not found"
    fi
    _WORKER_OUTPUT="$_CLUSTER_DIR/worker/output.json"
    if [ ! -f "$_WORKER_OUTPUT" ]; then
        _fail "worker output.json not found"
    fi
    _MASTER_NODES="$(jq -r '.node_private_ips.value | to_entries[] | "\(.key) ansible_host=\(.value)"' "$_MASTER_OUTPUT")"
    _WORKER_NODES="$(jq -r '.node_private_ips.value | to_entries[] | "\(.key) ansible_host=\(.value)"' "$_WORKER_OUTPUT")"
    _MASTER_SSH_PRIVATE_KEY="$(jq -r '.node_ssh_private_key.value' "$_MASTER_OUTPUT")"
    _WORKER_SSH_PRIVATE_KEY="$(jq -r '.node_ssh_private_key.value' "$_WORKER_OUTPUT")"
    _KUBESPRAY_DIR="$(_get_kubespray_dir)"
    if [ ! -d "$_KUBESPRAY_DIR" ]; then
        _fail "kubespray directory not found"
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
    rm -rf "$_CLUSTER_DIR/inventory"
    cp -r "$_KUBESPRAY_DIR/inventory/sample" "$_CLUSTER_DIR/inventory"
    cp "$ROCK8S_LIB_PATH/kubespray/vars.yml" "$_CLUSTER_DIR/inventory/vars.yml"
    cp "$ROCK8S_LIB_PATH/kubespray/postinstall.yml" "$_KUBESPRAY_DIR/postinstall.yml"
    cat >> "$_CLUSTER_DIR/inventory/vars.yml" <<EOF
enable_dual_stack_networks: $(_get_network_dualstack)
supplementary_addresses_in_ssl_keys: [$(_get_supplementary_addresses)]
calico_mtu: $(_get_network_mtu)
calico_veth_mtu: $((_get_network_mtu - 50))
metallb: "$(_get_network_metallb)"
EOF
    cat > "$_CLUSTER_DIR/inventory/inventory.ini" <<EOF
[kube_control_plane]
$(echo "$_MASTER_NODES") ansible_ssh_private_key_file=$_MASTER_SSH_PRIVATE_KEY

[etcd]
$(echo "$_MASTER_NODES") ansible_ssh_private_key_file=$_MASTER_SSH_PRIVATE_KEY

[kube_node]
$(echo "$_WORKER_NODES") ansible_ssh_private_key_file=$_WORKER_SSH_PRIVATE_KEY

[k8s-cluster:children]
kube_node
kube_control_plane

[kube_control_plane:vars]
node_labels={"topology.kubernetes.io/zone": "$_CLUSTER"}

[kube_node:vars]
node_labels={"topology.kubernetes.io/zone": "$_CLUSTER"}
EOF
    ANSIBLE_ROLES_PATH="$_KUBESPRAY_DIR/roles" \
        ANSIBLE_HOST_KEY_CHECKING=False \
        "$_KUBESPRAY_DIR/venv/bin/ansible-playbook" \
        -i "$_CLUSTER_DIR/inventory/inventory.ini" \
        -e "@$_CLUSTER_DIR/inventory/vars.yml" \
        -u admin --become --become-user=root \
        "$_KUBESPRAY_DIR/upgrade-cluster.yml" -b -v
    ANSIBLE_ROLES_PATH="$_KUBESPRAY_DIR/roles" \
        ANSIBLE_HOST_KEY_CHECKING=False \
        "$_KUBESPRAY_DIR/venv/bin/ansible-playbook" \
        -i "$_CLUSTER_DIR/inventory/inventory.ini" \
        -e "@$_CLUSTER_DIR/inventory/vars.yml" \
        -u admin --become --become-user=root \
        "$_KUBESPRAY_DIR/postinstall.yml" -b -v
    printf '{"name":"%s"}\n' "$_CLUSTER" | _format_output "$_FORMAT" cluster
}

_main "$@"
