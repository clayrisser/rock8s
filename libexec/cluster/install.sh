#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s cluster install

SYNOPSIS
       rock8s cluster install [-h] [-o <format>] [--cluster <cluster>] [-t <tenant>] [--update] [-y|--yes] [--pfsense-password <password>] [--pfsense-ssh-password]

DESCRIPTION
       install kubernetes cluster using kubespray

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format

       -t, --tenant <tenant>
              tenant name

       -c, --cluster <cluster>
              cluster name

       --update
              update ansible collections

       -y, --yes
              skip confirmation prompt

       --pfsense-password <password>
              admin password for pfsense configuration

       --pfsense-ssh-password
              use password authentication for ssh with pfsense

EXAMPLE
       # install kubernetes on existing nodes with automatic approval
       rock8s cluster install --cluster mycluster --yes

       # install kubernetes with a specific tenant
       rock8s cluster install --cluster mycluster --tenant mytenant

SEE ALSO
       rock8s cluster apply --help
       rock8s cluster addons --help
       rock8s cluster upgrade --help
EOF
}

_main() {
    _OUTPUT="${ROCK8S_OUTPUT}"
    _TENANT="$ROCK8S_TENANT"
    _CLUSTER="$ROCK8S_CLUSTER"
    _UPDATE=""
    _YES="0"
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
                        _OUTPUT="${1#*=}"
                        shift
                        ;;
                    *)
                        _OUTPUT="$2"
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
            -c|--cluster|-c=*|--cluster=*)
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
            --pfsense-ssh-password)
                _PFSENSE_SSH_PASSWORD="1"
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
    export ROCK8S_TENANT="$_TENANT"
    export ROCK8S_CLUSTER="$_CLUSTER"
    if [ -z "$ROCK8S_CLUSTER" ]; then
        fail "cluster name required"
    fi
    _KUBESPRAY_DIR="$(get_kubespray_dir)"
    if [ ! -d "$_KUBESPRAY_DIR" ]; then
        git clone --depth 1 --branch "$KUBESPRAY_VERSION" "$KUBESPRAY_REPO" "$_KUBESPRAY_DIR" >&2
    fi
    _VENV_DIR="$_KUBESPRAY_DIR/venv"
    if [ ! -d "$_VENV_DIR" ]; then
        python3 -m venv "$_VENV_DIR" >&2
    fi
    . "$_VENV_DIR/bin/activate"
    if command -v uv >/dev/null 2>&1; then
        uv pip install -r "$_KUBESPRAY_DIR/requirements.txt" >&2
    else
        pip install -r "$_KUBESPRAY_DIR/requirements.txt" >&2
    fi
    _INVENTORY_DIR="$(get_inventory_dir)"
    if [ ! -d "$_INVENTORY_DIR" ]; then
        cp -r "$_KUBESPRAY_DIR/inventory/sample" "$_INVENTORY_DIR"
    fi
    cp "$ROCK8S_LIB_PATH/kubespray/vars.yml" "$_INVENTORY_DIR/vars.yml"
    _MTU="$(get_network_mtu)"
    cp "$ROCK8S_LIB_PATH/kubespray/postinstall.yml" "$_KUBESPRAY_DIR/postinstall.yml"
    _LAN_METALLB="$(get_lan_metallb)"
    _ENABLE_DUALSTACK="$(get_enable_network_dualstack)"
    cat >> "$_INVENTORY_DIR/vars.yml" <<EOF
metallb_enabled: $([ -n "$_LAN_METALLB" ] && echo "true" || echo "false")
kube_proxy_strict_arp: $([ -n "$_LAN_METALLB" ] && echo "true" || echo "false")
enable_dual_stack_networks: $([ "$_ENABLE_DUALSTACK" = "1" ] && echo "true" || echo "false")
supplementary_addresses_in_ssl_keys: [$(get_supplementary_addresses)]
calico_mtu: $_MTU
calico_veth_mtu: $(($_MTU - 50))
metallb: "$_LAN_METALLB"
EOF
    _MASTER_ANSIBLE_PRIVATE_HOSTS="$(get_master_ansible_private_hosts)"
    _MASTER_SSH_PRIVATE_KEY="$(get_master_ssh_private_key)"
    _WORKER_ANSIBLE_PRIVATE_HOSTS="$(get_worker_ansible_private_hosts)"
    _WORKER_SSH_PRIVATE_KEY="$(get_worker_ssh_private_key)"
    cat > "$_INVENTORY_DIR/inventory.ini" <<EOF
[kube_control_plane]
$(echo "$_MASTER_ANSIBLE_PRIVATE_HOSTS" | sed "s|\(.*\)|\1 ansible_ssh_private_key_file=$_MASTER_SSH_PRIVATE_KEY|g")

[etcd]
$(echo "$_MASTER_ANSIBLE_PRIVATE_HOSTS" | sed "s|\(.*\)|\1 ansible_ssh_private_key_file=$_MASTER_SSH_PRIVATE_KEY|g")

[kube_node]
$(echo "$_WORKER_ANSIBLE_PRIVATE_HOSTS" | sed "s|\(.*\)|\1 ansible_ssh_private_key_file=$_WORKER_SSH_PRIVATE_KEY|g")

[k8s_cluster:children]
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
        "$_KUBESPRAY_DIR/cluster.yml" -b -v >&2
    ANSIBLE_ROLES_PATH="$_KUBESPRAY_DIR/roles" \
        ANSIBLE_HOST_KEY_CHECKING=False \
        "$_KUBESPRAY_DIR/venv/bin/ansible-playbook" \
        -i "$_INVENTORY_DIR/inventory.ini" \
        -e "@$_INVENTORY_DIR/vars.yml" \
        -u admin --become --become-user=root \
        "$_KUBESPRAY_DIR/postinstall.yml" -b -v >&2
    sh "$ROCK8S_LIB_PATH/libexec/pfsense/publish.sh" \
        --output="$_OUTPUT" \
        --cluster="$_CLUSTER" \
        --tenant="$_TENANT" \
        $([ -n "$_PFSENSE_PASSWORD" ] && echo "--password=$_PFSENSE_PASSWORD") \
        $([ "$_PFSENSE_SSH_PASSWORD" = "1" ] && echo "--ssh-password") >/dev/null
    sh "$ROCK8S_LIB_PATH/libexec/cluster/login.sh" \
        --output="$_OUTPUT" \
        --cluster="$_CLUSTER" \
        --tenant="$_TENANT" \
        --kubeconfig "$(get_cluster_dir)/kube.yaml" >/dev/null
    printf '{"name":"%s"}\n' "$_CLUSTER" | format_output "$_OUTPUT" cluster
}

_main "$@"
