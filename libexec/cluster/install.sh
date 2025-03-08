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
    _CLUSTER_DIR="$ROCK8S_STATE_HOME/tenants/$_TENANT/clusters/$_CLUSTER"
    if [ ! -d "$_CLUSTER_DIR" ]; then
        _fail "cluster $_CLUSTER not found"
    fi
    _CONFIG_FILE="$ROCK8S_CONFIG_HOME/tenants/$_TENANT/clusters/$_CLUSTER/config.yaml"
    if [ ! -f "$_CONFIG_FILE" ]; then
        _fail "cluster configuration file not found at $_CONFIG_FILE"
    fi
    _MASTER_OUTPUT="$_CLUSTER_DIR/master/output.json"
    if [ ! -f "$_MASTER_OUTPUT" ]; then
        _fail "master output.json not found"
    fi
    _WORKER_OUTPUT="$_CLUSTER_DIR/worker/output.json"
    if [ ! -f "$_WORKER_OUTPUT" ]; then
        _fail "worker output.json not found"
    fi
    _NETWORK_SUBNET="$(yaml2json < "$_CONFIG_FILE" | jq -r '.network.lan.subnet')"
    if [ -z "$_NETWORK_SUBNET" ] || [ "$_NETWORK_SUBNET" = "null" ]; then
        _fail ".network.lan.subnet not found in config.yaml"
    fi
    _ENTRYPOINT="$(yaml2json < "$_CONFIG_FILE" | jq -r '.network.entrypoint')"
    if [ -z "$_ENTRYPOINT" ] || [ "$_ENTRYPOINT" = "null" ]; then
        _fail ".network.entrypoint not found in config.yaml"
    fi
    _MASTER_NODES="$(jq -r '.node_private_ips.value | to_entries[] | "\(.key) ansible_host=\(.value)"' "$_MASTER_OUTPUT")"
    _MASTER_IPV4S="$(jq -r '.node_private_ips.value | .[] | @text' "$_MASTER_OUTPUT")"
    _MASTER_EXTERNAL_IPV4S="$(jq -r '.node_ips.value | .[] | @text' "$_MASTER_OUTPUT")"
    _ENTRYPOINT_IPV4="$(_resolve_hostname "$_ENTRYPOINT")"
    _SUPPLEMENTARY_ADDRESSES="\"$_ENTRYPOINT\""
    if [ -n "$_ENTRYPOINT_IPV4" ]; then
        _SUPPLEMENTARY_ADDRESSES="$_SUPPLEMENTARY_ADDRESSES,\"$_ENTRYPOINT_IPV4\""
    fi
    for _IPV4 in $_MASTER_IPV4S; do
        _SUPPLEMENTARY_ADDRESSES="$_SUPPLEMENTARY_ADDRESSES,\"$_IPV4\""
    done
    for _IPV4 in $_MASTER_EXTERNAL_IPV4S; do
        _SUPPLEMENTARY_ADDRESSES="$_SUPPLEMENTARY_ADDRESSES,\"$_IPV4\""
    done
    _WORKER_NODES="$(jq -r '.node_private_ips.value | to_entries[] | "\(.key) ansible_host=\(.value)"' "$_WORKER_OUTPUT")"
    _MASTER_SSH_PRIVATE_KEY="$(jq -r '.node_ssh_private_key.value' "$_MASTER_OUTPUT")"
    _WORKER_SSH_PRIVATE_KEY="$(jq -r '.node_ssh_private_key.value' "$_WORKER_OUTPUT")"
    _KUBESPRAY_DIR="$_CLUSTER_DIR/kubespray"
    _ensure_system
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
    if [ ! -d "$_CLUSTER_DIR/inventory" ]; then
        cp -r "$_KUBESPRAY_DIR/inventory/sample" "$_CLUSTER_DIR/inventory"
    fi
    cp "$ROCK8S_LIB_PATH/kubespray/vars.yml" "$_CLUSTER_DIR/inventory/vars.yml"
    _MTU="$(yaml2json < "$_CONFIG_FILE" | jq -r '.network.lan.mtu')"
    if [ -z "$_MTU" ] || [ "$_MTU" = "null" ]; then
        _MTU="1500"
    fi
    _DUELSTACK="$(yaml2json < "$_CONFIG_FILE" | jq -r '.network.lan.dualstack')"
    if [ "$_DUELSTACK" = "false" ]; then
        _DUELSTACK="false"
    else
        _DUELSTACK="true"
    fi
    _METALLB="$(yaml2json < "$_CONFIG_FILE" | jq -r '.network.lan.metallb')"
    if [ -z "$_METALLB" ] || [ "$_METALLB" = "null" ]; then
        _METALLB="$(_calculate_metallb "$_NETWORK_SUBNET")"
    fi
    cp "$ROCK8S_LIB_PATH/kubespray/postinstall.yml" "$_KUBESPRAY_DIR/postinstall.yml"
    cat >> "$_CLUSTER_DIR/inventory/vars.yml" <<EOF

enable_dual_stack_networks: $_DUELSTACK
supplementary_addresses_in_ssl_keys: [$_SUPPLEMENTARY_ADDRESSES]
calico_mtu: $_MTU
calico_veth_mtu: $(($_MTU - 50))
metallb: "$_METALLB"
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
        "$_KUBESPRAY_DIR/cluster.yml" -b -v
    ANSIBLE_ROLES_PATH="$_KUBESPRAY_DIR/roles" \
        ANSIBLE_HOST_KEY_CHECKING=False \
        "$_KUBESPRAY_DIR/venv/bin/ansible-playbook" \
        -i "$_CLUSTER_DIR/inventory/inventory.ini" \
        -e "@$_CLUSTER_DIR/inventory/vars.yml" \
        -u admin --become --become-user=root \
        "$_KUBESPRAY_DIR/postinstall.yml" -b -v
    "$ROCK8S_LIB_PATH/libexec/cluster/login.sh" --cluster "$_CLUSTER" --tenant "$_TENANT" --kubeconfig "$_CLUSTER_DIR/kube.yaml" --output json > /dev/null
    printf '{"name":"%s"}\n' "$_CLUSTER" | _format_output "$_FORMAT" cluster
}

_main "$@"
