#!/bin/sh

_get_kubespray_dir() {
    _CLUSTER_DIR="$1"
    echo "$_CLUSTER_DIR/kubespray"
}

_get_kubespray_venv_dir() {
    _KUBESPRAY_DIR="$1"
    echo "$_KUBESPRAY_DIR/venv"
}

_get_kubespray_inventory_dir() {
    _CLUSTER_DIR="$1"
    echo "$_CLUSTER_DIR/inventory"
}

_get_kubespray_inventory_file() {
    _INVENTORY_DIR="$1"
    echo "$_INVENTORY_DIR/inventory.ini"
}

_validate_kubespray_dir() {
    _KUBESPRAY_DIR="$1"
    if [ ! -d "$_KUBESPRAY_DIR" ]; then
        _fail "kubespray directory not found at $_KUBESPRAY_DIR"
    fi
}

_validate_kubespray_venv() {
    _VENV_DIR="$1"
    if [ ! -d "$_VENV_DIR" ]; then
        _fail "kubespray virtual environment not found"
    fi
}

_validate_kubespray_inventory() {
    _INVENTORY_FILE="$1"
    if [ ! -f "$_INVENTORY_FILE" ]; then
        _fail "inventory file not found at $_INVENTORY_FILE"
    fi
}

_setup_kubespray() {
    _CLUSTER_DIR="$1"
    _KUBESPRAY_DIR="$(_get_kubespray_dir "$_CLUSTER_DIR")"
    
    # Clone Kubespray if not exists
    if [ ! -d "$_KUBESPRAY_DIR" ]; then
        git clone --depth 1 --branch "$KUBESPRAY_VERSION" "$KUBESPRAY_REPO" "$_KUBESPRAY_DIR"
    fi
    
    # Setup virtual environment
    _VENV_DIR="$(_get_kubespray_venv_dir "$_KUBESPRAY_DIR")"
    if [ ! -d "$_VENV_DIR" ]; then
        python3 -m venv "$_VENV_DIR"
    fi
    . "$_VENV_DIR/bin/activate"
    
    # Install requirements
    if command -v uv >/dev/null 2>&1; then
        uv pip install -r "$_KUBESPRAY_DIR/requirements.txt"
    else
        pip install -r "$_KUBESPRAY_DIR/requirements.txt"
    fi
}

_setup_kubespray_inventory() {
    _CLUSTER_DIR="$1"
    _KUBESPRAY_DIR="$(_get_kubespray_dir "$_CLUSTER_DIR")"
    _INVENTORY_DIR="$(_get_kubespray_inventory_dir "$_CLUSTER_DIR")"
    
    # Copy sample inventory if not exists
    if [ ! -d "$_INVENTORY_DIR" ]; then
        cp -r "$_KUBESPRAY_DIR/inventory/sample" "$_INVENTORY_DIR"
    fi
    
    # Copy vars.yml
    cp "$ROCK8S_LIB_PATH/kubespray/vars.yml" "$_INVENTORY_DIR/vars.yml"
    
    # Get network settings
    _MTU="$(_get_network_mtu)"
    _DUELSTACK="$(_get_network_dualstack)"
    _METALLB="$(_get_lan_metallb)"
    _SUPPLEMENTARY_ADDRESSES="$(_get_supplementary_addresses)"
    
    # Copy postinstall.yml
    cp "$ROCK8S_LIB_PATH/kubespray/postinstall.yml" "$_KUBESPRAY_DIR/postinstall.yml"
    
    # Append network settings to vars.yml
    cat >> "$_INVENTORY_DIR/vars.yml" <<EOF

enable_dual_stack_networks: $_DUELSTACK
supplementary_addresses_in_ssl_keys: [$_SUPPLEMENTARY_ADDRESSES]
calico_mtu: $_MTU
calico_veth_mtu: $(($_MTU - 50))
metallb: "$_METALLB"
EOF
}

_create_kubespray_inventory() {
    _CLUSTER_DIR="$1"
    _INVENTORY_DIR="$(_get_kubespray_inventory_dir "$_CLUSTER_DIR")"
    _MASTER_NODES="$(_get_node_private_ips "master")"
    _MASTER_SSH_PRIVATE_KEY="$(_get_node_ssh_key "master")"
    _WORKER_NODES="$(_get_node_private_ips "worker")"
    _WORKER_SSH_PRIVATE_KEY="$(_get_node_ssh_key "worker")"
    
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
}

_run_kubespray_playbook() {
    _CLUSTER_DIR="$1"
    _PLAYBOOK="$2"
    _EXTRA_VARS="${3:-}"
    _KUBESPRAY_DIR="$(_get_kubespray_dir "$_CLUSTER_DIR")"
    _INVENTORY_DIR="$(_get_kubespray_inventory_dir "$_CLUSTER_DIR")"
    ANSIBLE_ROLES_PATH="$_KUBESPRAY_DIR/roles" \
        ANSIBLE_HOST_KEY_CHECKING=False \
        "$_KUBESPRAY_DIR/venv/bin/ansible-playbook" \
        -i "$_INVENTORY_DIR/inventory.ini" \
        -e "@$_INVENTORY_DIR/vars.yml" \
        $_EXTRA_VARS \
        -u admin --become --become-user=root \
        "$_KUBESPRAY_DIR/$_PLAYBOOK" -b -v
}
