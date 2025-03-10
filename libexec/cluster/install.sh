#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s cluster install - install kubernetes cluster

SYNOPSIS
       rock8s cluster install [-h] [-o <format>] [--cluster <cluster>] [-t <tenant>] [--update]

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
EOF
}

_main() {
    _FORMAT="${ROCK8S_OUTPUT_FORMAT:-text}"
    _CLUSTER="$ROCK8S_CLUSTER"
    _TENANT="$ROCK8S_TENANT"
    _UPDATE=""
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
    
    _CLUSTER_DIR="$(_get_cluster_dir "$_TENANT" "$_CLUSTER")"
    _validate_cluster_dir "$_CLUSTER_DIR"
    
    # Get node information
    _MASTER_NODES="$(_get_node_private_ips "master")"
    _MASTER_SSH_PRIVATE_KEY="$(_get_node_ssh_key "master")"
    _WORKER_NODES="$(_get_node_private_ips "worker")"
    _WORKER_SSH_PRIVATE_KEY="$(_get_node_ssh_key "worker")"
    
    # Setup Kubespray
    _KUBESPRAY_DIR="$(_get_kubespray_dir "$_CLUSTER_DIR")"
    if [ ! -d "$_KUBESPRAY_DIR" ]; then
        git clone --depth 1 --branch "$KUBESPRAY_VERSION" "$KUBESPRAY_REPO" "$_KUBESPRAY_DIR"
    fi
    
    _VENV_DIR="$(_get_kubespray_venv_dir "$_KUBESPRAY_DIR")"
    if [ ! -d "$_VENV_DIR" ]; then
        python3 -m venv "$_VENV_DIR"
    fi
    . "$_VENV_DIR/bin/activate"
    
    if command -v uv >/dev/null 2>&1; then
        uv pip install -r "$_KUBESPRAY_DIR/requirements.txt"
    else
        pip install -r "$_KUBESPRAY_DIR/requirements.txt"
    fi
    
    # Setup inventory
    _INVENTORY_DIR="$(_get_kubespray_inventory_dir "$_CLUSTER_DIR")"
    if [ ! -d "$_INVENTORY_DIR" ]; then
        cp -r "$_KUBESPRAY_DIR/inventory/sample" "$_INVENTORY_DIR"
    fi
    
    cp "$ROCK8S_LIB_PATH/kubespray/vars.yml" "$_INVENTORY_DIR/vars.yml"
    
    # Get network settings
    _MTU="$(_get_network_mtu)"
    _DUELSTACK="$(_get_network_dualstack)"
    _METALLB="$(_get_lan_metallb)"
    _SUPPLEMENTARY_ADDRESSES="$(_get_supplementary_addresses)"
    
    cp "$ROCK8S_LIB_PATH/kubespray/postinstall.yml" "$_KUBESPRAY_DIR/postinstall.yml"
    cat >> "$_INVENTORY_DIR/vars.yml" <<EOF

enable_dual_stack_networks: $_DUELSTACK
supplementary_addresses_in_ssl_keys: [$_SUPPLEMENTARY_ADDRESSES]
calico_mtu: $_MTU
calico_veth_mtu: $(($_MTU - 50))
metallb: "$_METALLB"
EOF
    
    cat > "$_INVENTORY_DIR/inventory.ini" <<EOF
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
    
    "$ROCK8S_LIB_PATH/libexec/cluster/login.sh" --cluster "$_CLUSTER" --tenant "$_TENANT" --kubeconfig "$_CLUSTER_DIR/kube.yaml" --output json > /dev/null
    printf '{"name":"%s"}\n' "$_CLUSTER" | _format_output "$_FORMAT" cluster
}

_main "$@"
