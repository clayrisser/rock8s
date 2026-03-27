#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/libexec/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s pfsense apply

SYNOPSIS
       rock8s pfsense apply [-h] [-o <format>] [--name <name>] [-t <tenant>] [--update] [--password <password>] [--ssh-password] [-y|--yes]

DESCRIPTION
       provision and configure pfsense firewall nodes

OPTIONS
       -h, --help
              show this help message

       -o, --output=<format>
              output format

       -t, --tenant <tenant>
              tenant name

       -n, --name <name>
              pfsense instance name

       --update
              update ansible collections

       --password <password>
              admin password

       --ssh-password
              use password authentication for ssh

       -y, --yes
              skip confirmation prompt

EXAMPLE
       # provision and configure pfsense
       rock8s pfsense apply --name mypfsense --yes

       # provision with a specific password
       rock8s pfsense apply --name mypfsense --password mypassword

SEE ALSO
       rock8s pfsense configure --help
       rock8s pfsense destroy --help
EOF
}

_main() {
    output="${ROCK8S_OUTPUT}"
    tenant="$ROCK8S_TENANT"
    pfsense="$ROCK8S_PFSENSE"
    update=""
    password=""
    ssh_password=0
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
            --password|--password=*)
                case "$1" in
                    *=*)
                        password="${1#*=}"
                        shift
                        ;;
                    *)
                        password="$2"
                        shift 2
                        ;;
                esac
                ;;
            --ssh-password)
                ssh_password=1
                shift
                ;;
            --update)
                update="1"
                shift
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
    provider="$(get_provider)"
    mkdir -p "$pfsense_dir"
    if is_pfsense_provisioned; then
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
        tofu apply $([ "$yes" = "1" ] && echo "-auto-approve" || true) -var-file="$pfsense_dir/terraform.tfvars.json" >&2
        tofu output -json > "$pfsense_dir/output.json"
        extract_ssh_private_key "$pfsense_dir/output.json" "$pfsense_dir/id_rsa"
    else
        log "using existing pfSense appliance (no node type specified in config)"
    fi
    sh "$ROCK8S_LIB_PATH/libexec/pfsense/configure.sh" \
        --output="$output" \
        --name="$pfsense" \
        --tenant="$tenant" \
        $([ "$update" = "1" ] && echo "--update") \
        $([ -n "$password" ] && echo "--password '$password'") \
        $([ "$ssh_password" = "1" ] && echo "--ssh-password") >/dev/null
    printf '{"pfsense":"%s","provider":"%s","tenant":"%s"}\n' \
        "$pfsense" "$provider" "$tenant" | \
        format_output "$output"
}

_main "$@"
