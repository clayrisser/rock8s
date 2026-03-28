#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s nodes apply

SYNOPSIS
       rock8s nodes apply [-h] [-o <format>] [--cluster <cluster>] [--force] <purpose>

DESCRIPTION
       create new cluster nodes or update existing ones for a specific purpose (master or worker)

ARGUMENTS
       purpose
              purpose of the nodes (master or worker)

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format

       -c, --cluster <cluster>
              cluster name

       --force
              skip dependency checks

       -y, --yes
              skip confirmation prompt

EXAMPLE
       # create master nodes
       rock8s nodes apply --cluster mycluster master

       # create worker nodes
       rock8s nodes apply --cluster mycluster worker

       # update existing nodes with automatic approval
       rock8s nodes apply --cluster mycluster --yes worker

SEE ALSO
       rock8s nodes destroy --help
       rock8s nodes ls --help
       rock8s nodes ssh --help
EOF
}

_main() {
    output="${ROCK8S_OUTPUT}"
    purpose=""
    cluster="$ROCK8S_CLUSTER"
    force=0
    yes=0
    while test $# -gt 0; do
        case "$1" in
        -h | --help)
            _help
            exit
            ;;
        -o | --output | -o=* | --output=*)
            case "$1" in
            *=*)
                output="${1#*=}"
                shift
                ;;
            *)
                output="$2"
                shift 2
                ;;
            esac
            ;;
        -c | --cluster | -c=* | --cluster=*)
            case "$1" in
            *=*)
                cluster="${1#*=}"
                shift
                ;;
            *)
                cluster="$2"
                shift 2
                ;;
            esac
            ;;
        --force)
            force=1
            shift
            ;;
        -y | --yes)
            yes=1
            shift
            ;;
        -*)
            _help
            exit 1
            ;;
        *)
            if [ -z "$purpose" ]; then
                purpose="$1"
                shift
            else
                _help
                exit 1
            fi
            ;;
        esac
    done
    if [ -z "$purpose" ]; then
        _help
        exit 1
    fi
    if ! echo "$purpose" | grep -qE '^(master|worker)$'; then
        fail "$purpose is invalid"
    fi
    export ROCK8S_CLUSTER="$cluster"
    if [ -z "$ROCK8S_CLUSTER" ]; then
        fail "cluster name required"
    fi
    cluster_dir="$(get_cluster_dir)"
    provider="$(get_provider)"
    purpose_dir="$cluster_dir/$purpose"
    if [ ! -d "$purpose_dir" ] || [ ! -f "$purpose_dir/output.json" ]; then
        if [ "$force" != "1" ]; then
            case "$purpose" in
            worker)
                if [ ! -d "$cluster_dir/master" ]; then
                    fail "master nodes must be created before worker nodes"
                fi
                ;;
            esac
        fi
    fi
    mkdir -p "$purpose_dir"
    provider_dir="$ROCK8S_HOME/providers/$provider"
    if [ ! -d "$provider_dir" ]; then
        fail "provider $provider not found"
    fi
    rm -rf "$cluster_dir/provider"
    cp -r "$provider_dir" "$cluster_dir/provider"
    state_key="$(get_state_key "$cluster" "$purpose")"
    write_backend_config "$cluster_dir/provider" "$state_key" "$purpose_dir"
    export TF_VAR_cluster_name="$cluster"
    export TF_VAR_purpose="$purpose"
    export TF_DATA_DIR="$purpose_dir/.terraform"
    config_json="$(get_config_json)"
    echo "$config_json" | . "$cluster_dir/provider/tfvars.sh" >"$purpose_dir/terraform.tfvars.json"
    chmod 600 "$purpose_dir/terraform.tfvars.json"
    if [ -f "$cluster_dir/provider/variables.sh" ]; then
        . "$cluster_dir/provider/variables.sh"
    fi
    cd "$cluster_dir/provider"
    tofu init -upgrade -reconfigure >&2
    tofu apply $([ "$yes" = "1" ] && echo "-auto-approve" || true) -var-file="$purpose_dir/terraform.tfvars.json" >&2
    tofu output -json >"$purpose_dir/output.json"
    extract_ssh_private_key "$purpose_dir/output.json" "$purpose_dir/id_rsa"
    printf '{"cluster":"%s","provider":"%s","purpose":"%s"}\n' \
        "$cluster" "$provider" "$purpose" |
        format_output "$output"
}

_main "$@"
