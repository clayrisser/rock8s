#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s cluster create - create kubernetes cluster

SYNOPSIS
       rock8s cluster create [-h] [-o <format>] <name>

DESCRIPTION
       create a new kubernetes cluster using kubespray

ARGUMENTS
       name
              name of the cluster to create

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

    _validate_cluster_name "$_NAME"
    _CLUSTER_DIR="$(_get_cluster_dir "$_NAME")"
    _KUBESPRAY_CLUSTER_DIR="$_CLUSTER_DIR/kubespray"

    # Clone Kubespray if not already present
    if [ ! -d "$ROCK8S_KUBESPRAY_PATH" ]; then
        _log "Cloning Kubespray repository..."
        git clone https://github.com/kubernetes-sigs/kubespray.git "$ROCK8S_KUBESPRAY_PATH"
    fi

    # Create cluster directory structure
    mkdir -p "$_KUBESPRAY_CLUSTER_DIR"
    cp -rfp "$ROCK8S_KUBESPRAY_PATH/inventory/sample"/* "$_KUBESPRAY_CLUSTER_DIR/"

    # Initialize Python virtual environment
    _log "Initializing Python virtual environment..."
    python3 -m venv "$_KUBESPRAY_CLUSTER_DIR/venv"
    . "$_KUBESPRAY_CLUSTER_DIR/venv/bin/activate"
    pip install -r "$ROCK8S_KUBESPRAY_PATH/requirements.txt"

    # Check if we have nodes.json from a provider
    if [ -f "$_CLUSTER_DIR/nodes.json" ]; then
        _log "Generating inventory from nodes.json..."
        python "$ROCK8S_LIB_PATH/libexec/kubespray/generate_inventory.py" \
            --nodes "$_CLUSTER_DIR/nodes.json" \
            --output "$_KUBESPRAY_CLUSTER_DIR/inventory.yml"
    fi

    # Verify inventory exists
    [ ! -f "$_KUBESPRAY_CLUSTER_DIR/inventory.yml" ] && {
        _fail "no inventory file found at $_KUBESPRAY_CLUSTER_DIR/inventory.yml"
    }

    # Run the Kubespray playbook
    _log "Running Kubespray playbook..."
    ansible-playbook -i "$_KUBESPRAY_CLUSTER_DIR/inventory.yml" \
        "$ROCK8S_KUBESPRAY_PATH/cluster.yml" \
        -b -v "$@"

    # Save kubeconfig
    _log "Saving kubeconfig..."
    mkdir -p "$_CLUSTER_DIR/auth"
    ansible -i "$_KUBESPRAY_CLUSTER_DIR/inventory.yml" \
        -m fetch -a "src=/etc/kubernetes/admin.conf dest=$_CLUSTER_DIR/auth/kubeconfig flat=yes" \
        kube_control_plane[0]

    printf '{"name":"%s"}\n' "$_NAME" | _format_output "$_FORMAT" cluster
}

_main "$@"
