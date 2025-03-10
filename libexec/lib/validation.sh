#!/bin/sh

_validate_kubeconfig() {
    _KUBECONFIG="$1"
    [ -f "$_KUBECONFIG" ] || {
        _fail "kubeconfig not found: $_KUBECONFIG"
    }
}

_validate_cluster_config() {
    _CONFIG_FILE="$1"
}

_validate_cluster_dir() {
    _CLUSTER_DIR="$1"
    if [ ! -d "$_CLUSTER_DIR" ]; then
        _fail "cluster state directory not found at $_CLUSTER_DIR"
    fi
}

_validate_cluster_node() {
    _CLUSTER_DIR="$1"
    _NODE_TYPE="$2"
    if [ ! -d "$_CLUSTER_DIR/$_NODE_TYPE" ]; then
        _fail "$_NODE_TYPE node directory not found"
    fi
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

_validate_node_output() {
    _OUTPUT_FILE="$1"
    _NODE_TYPE="$2"
    if [ ! -f "$_OUTPUT_FILE" ]; then
        _fail "$_NODE_TYPE output.json not found"
    fi
}
