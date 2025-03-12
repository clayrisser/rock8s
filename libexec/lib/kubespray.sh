#!/bin/sh

_get_kubespray_dir() {
    if [ -n "$_KUBESPRAY_DIR" ]; then
        echo "$_KUBESPRAY_DIR"
        return
    fi
    _KUBESPRAY_DIR="$(_get_cluster_dir)/kubespray"
    echo "$_KUBESPRAY_DIR"
}

_get_inventory_dir() {
    if [ -n "$_INVENTORY_DIR" ]; then
        echo "$_INVENTORY_DIR"
        return
    fi
    _INVENTORY_DIR="$(_get_cluster_dir)/inventory"
    echo "$_INVENTORY_DIR"
}
