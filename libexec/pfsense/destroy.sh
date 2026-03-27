#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s pfsense destroy

SYNOPSIS
       rock8s pfsense destroy [-h] [-o <format>] [--name <name>] [-t <tenant>] [-y|--yes]

DESCRIPTION
       destroy pfsense firewall nodes

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format

       -t, --tenant <tenant>
              tenant name

       -n, --name <name>
              pfsense instance name

       -y, --yes
              skip confirmation prompt

EXAMPLE
       # destroy pfsense with confirmation
       rock8s pfsense destroy --name mypfsense

       # destroy pfsense without confirmation
       rock8s pfsense destroy --name mypfsense --yes

SEE ALSO
       rock8s pfsense apply --help
       rock8s pfsense configure --help
EOF
}

_main() {
    output="${ROCK8S_OUTPUT}"
    tenant="$ROCK8S_TENANT"
    pfsense="$ROCK8S_PFSENSE"
    yes=0
    while test $# -gt 0; do
        case "$1" in
            -h|--help)
                _help
                exit
                ;;
            -o|--output|-o=*|--output=*)
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
            -t|--tenant|-t=*|--tenant=*)
                case "$1" in
                    *=*)
                        tenant="${1#*=}"
                        shift
                        ;;
                    *)
                        tenant="$2"
                        shift 2
                        ;;
                esac
                ;;
            -n|--name|-n=*|--name=*)
                case "$1" in
                    *=*)
                        pfsense="${1#*=}"
                        shift
                        ;;
                    *)
                        pfsense="$2"
                        shift 2
                        ;;
                esac
                ;;
            -y|--yes)
                yes=1
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
    export ROCK8S_PFSENSE="$pfsense"
    export ROCK8S_TENANT="$tenant"
    if [ -z "$ROCK8S_PFSENSE" ]; then
        fail "pfsense name required"
    fi
    pfsense_dir="$(get_pfsense_dir)"
    if [ ! -d "$pfsense_dir" ]; then
        fail "pfsense $pfsense not found"
    fi
    if is_pfsense_provisioned; then
        if [ ! -f "$pfsense_dir/output.json" ]; then
            fail "pfsense $pfsense state not found"
        fi
        provider="$(get_provider)"
        provider_dir="$ROCK8S_LIB_PATH/providers/$provider"
        if [ ! -d "$provider_dir" ]; then
            fail "provider $provider not found"
        fi
        rm -rf "$pfsense_dir/provider"
        cp -r "$provider_dir" "$pfsense_dir/provider"
        state_key="$(get_state_key "$tenant" "$pfsense" "pfsense")"
        write_backend_config "$pfsense_dir/provider" "$state_key" "$pfsense_dir"
        export TF_VAR_cluster_name="$pfsense"
        export TF_VAR_purpose="pfsense"
        export TF_VAR_tenant="$tenant"
        export TF_DATA_DIR="$pfsense_dir/.terraform"
        config_json="$(get_config_json)"
        echo "$config_json" | . "$pfsense_dir/provider/tfvars.sh" > "$pfsense_dir/terraform.tfvars.json"
        chmod 600 "$pfsense_dir/terraform.tfvars.json"
        if [ -f "$pfsense_dir/provider/variables.sh" ]; then
            . "$pfsense_dir/provider/variables.sh"
        fi
        cd "$pfsense_dir/provider"
        tofu init -upgrade -reconfigure >&2
        tofu destroy $([ "$yes" = "1" ] && echo "-auto-approve" || true) -var-file="$pfsense_dir/terraform.tfvars.json" >&2
    else
        warn "pfSense is an existing appliance, skipping infrastructure destruction"
    fi
    rm -rf "$pfsense_dir"
    printf '{"pfsense":"%s","provider":"%s","tenant":"%s"}\n' \
        "$pfsense" "$provider" "$tenant" | \
        format_output "$output"
}

_main "$@"
