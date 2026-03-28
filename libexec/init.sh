#!/bin/sh

set -e

. "$ROCK8S_LIB_PATH/lib.sh"

_help() {
    cat <<EOF >&2
NAME
       rock8s init

SYNOPSIS
       rock8s init [-h] [-y|--yes] [<path>]

DESCRIPTION
       initialize a new rock8s configuration file

       walks through provider, networking, nodes, state backend and addons
       to generate a starter rock8s.yaml

ARGUMENTS
       path
              output path for the config file (default: rock8s.yaml)

OPTIONS
       -h, --help
              show this help message

       -y, --yes
              use defaults without prompting

EXAMPLE
       # create a new rock8s.yaml in the current directory
       rock8s init

       # create a config file at a specific path
       rock8s init ./clusters/production.yaml

       # create a config with all defaults (no prompts)
       rock8s init --yes

SEE ALSO
       rock8s nodes apply --help
       rock8s cluster apply --help
EOF
}

_prompt() {
    _label="$1"
    _default="$2"
    if [ "$_YES" = "1" ]; then
        echo "$_default"
        return
    fi
    if command -v dialog >/dev/null 2>&1 && [ -t 0 ]; then
        _result=$(dialog --stdout --inputbox "$_label" 0 50 "$_default") || exit 0
        echo "$_result"
    else
        if [ -n "$_default" ]; then
            printf "  %s [%s]: " "$_label" "$_default" >&2
        else
            printf "  %s: " "$_label" >&2
        fi
        read -r _value
        echo "${_value:-$_default}"
    fi
}

_prompt_yn() {
    _label="$1"
    _default="$2"
    if [ "$_YES" = "1" ]; then
        echo "$_default"
        return
    fi
    if command -v dialog >/dev/null 2>&1 && [ -t 0 ]; then
        if [ "$_default" = "n" ]; then
            dialog --stdout --defaultno --yesno "$_label" 0 0 && echo "y" || echo "n"
        else
            dialog --stdout --yesno "$_label" 0 0 && echo "y" || echo "n"
        fi
    else
        printf "  %s [%s]: " "$_label" "$_default" >&2
        read -r _value
        _value="${_value:-$_default}"
        case "$_value" in
        y | Y | yes | Yes | YES) echo "y" ;;
        *) echo "n" ;;
        esac
    fi
}

_dialog_menu() {
    _title="$1"
    _default="$2"
    shift 2
    if [ "$_YES" = "1" ]; then
        echo "$_default"
        return
    fi
    if command -v dialog >/dev/null 2>&1 && [ -t 0 ]; then
        dialog --stdout --default-item "$_default" --menu "$_title" 0 0 0 "$@" || exit 0
    else
        _opts=""
        while [ $# -ge 2 ]; do
            _opts="${_opts:+$_opts, }$1"
            shift 2
        done
        _prompt "$_title ($_opts)" "$_default"
    fi
}

_dialog_checklist() {
    _title="$1"
    shift
    if [ "$_YES" = "1" ]; then
        while [ $# -ge 3 ]; do
            [ "$3" = "on" ] && printf "%s " "$1"
            shift 3
        done
        return
    fi
    if command -v dialog >/dev/null 2>&1 && [ -t 0 ]; then
        _result=$(dialog --stdout --checklist "$_title" 0 0 0 "$@") || exit 0
        printf "%s" "$_result" | tr -d '"'
    else
        while [ $# -ge 3 ]; do
            _tag="$1"
            _desc="$2"
            _state="$3"
            shift 3
            [ "$_state" = "on" ] && _def="y" || _def="n"
            _val=$(_prompt_yn "$_tag ($_desc)" "$_def")
            [ "$_val" = "y" ] && printf "%s " "$_tag"
        done
    fi
}

_has_addon() {
    for _a in $_addon_selection; do
        [ "$_a" = "$1" ] && return 0
    done
    return 1
}

_write_config() {
    _out="$1"
    {
        echo "provider:"
        echo "  type: $provider"
        printf '%s\n' "$_provider_yaml"
        if [ -n "$location" ]; then
            echo ""
            echo "location: $location"
        fi
        if [ -n "$image" ]; then
            echo "image: $image"
        fi
        echo ""
        echo "network:"
        echo "  entrypoint: $entrypoint"
        if [ -n "$gateway" ]; then
            echo "  gateway: $gateway"
        fi
        echo "  lan:"
        echo "    name: $lan_name"
        if [ -n "$_lan_resource_group" ]; then
            echo "    resource_group: $_lan_resource_group"
        fi
        if [ -n "$lan_subnet" ]; then
            echo "    ipv4:"
            echo "      subnet: $lan_subnet"
        fi
        echo ""
        echo "masters:"
        echo "  - type: $master_type"
        echo ""
        echo "workers:"
        echo "  - type: $worker_type"
        echo "    count: $worker_count"
        if [ -n "$_state_yaml" ]; then
            echo ""
            printf '%s\n' "$_state_yaml"
        fi
        if [ -n "$_addons_yaml" ]; then
            echo ""
            echo "addons:"
            if [ "$ROCK8S_DEBUG" != "1" ]; then
                echo "  source:"
                echo "    version: $ROCK8S_VERSION"
            fi
            if [ -n "$_email" ]; then
                echo "  email: $_email"
            fi
            printf '%s\n' "$_addons_yaml"
        fi
    } >"$_out"
}

_main() {
    config_path="${ROCK8S_CONFIG:-rock8s.yaml}"
    _YES=0
    while test $# -gt 0; do
        case "$1" in
        -h | --help)
            _help
            exit
            ;;
        -y | --yes)
            _YES=1
            shift
            ;;
        -*)
            _help
            exit 1
            ;;
        *)
            config_path="$1"
            shift
            ;;
        esac
    done
    if [ -f "$config_path" ]; then
        fail "config file already exists: $config_path"
    fi

    log "initializing new configuration"
    echo >&2

    # --- provider ---
    _provider_init_dir="$ROCK8S_HOME/providers"
    _provider_menu=""
    for _p in "$_provider_init_dir"/*/; do
        [ -d "$_p" ] || continue
        _pname="$(basename "$_p")"
        _provider_menu="$_provider_menu $_pname $_pname"
    done
    provider="$(_dialog_menu "Select provider" "hetzner" $_provider_menu)"
    _provider_init="$_provider_init_dir/$provider/init.sh"
    if [ ! -f "$_provider_init" ]; then
        fail "provider $provider has no init.sh"
    fi
    location=""
    image=""
    lan_subnet=""
    . "$_provider_init"

    # --- network ---
    printf "${BLUE}network${NC}\n" >&2
    entrypoint="$(_prompt "entrypoint (DNS hostname)" "cluster.example.com")"
    gateway="$(_prompt "LAN gateway IP (leave empty for WAN-only)" "")"
    lan_name="$(_prompt "LAN network name" "")"
    echo >&2

    # --- state backend ---
    state_backend="$(_dialog_menu "Select state backend" "local" \
        local "Local filesystem" \
        s3 "S3-compatible storage" \
        gcs "Google Cloud Storage" \
        azblob "Azure Blob Storage")"
    _state_yaml=""
    case "$state_backend" in
    s3)
        _s3_bucket="$(_prompt "bucket" "")"
        _s3_region="$(_prompt "region" "us-east-1")"
        _s3_endpoint="$(_prompt "endpoint (leave empty for AWS)" "")"
        _s3_access_key="$(_prompt "access_key" "ref+env://AWS_ACCESS_KEY_ID")"
        _s3_secret_key="$(_prompt "secret_key" "ref+env://AWS_SECRET_ACCESS_KEY")"
        _s3_lock="$(_prompt_yn "enable state locking (requires S3 conditional writes)" "y")"
        _state_yaml="state:
  backend: s3
  bucket: $_s3_bucket
  region: $_s3_region
  access_key: $_s3_access_key
  secret_key: $_s3_secret_key"
        if [ -n "$_s3_endpoint" ]; then
            _state_yaml="$_state_yaml
  endpoint: $_s3_endpoint"
        fi
        if [ "$_s3_lock" = "n" ]; then
            _state_yaml="$_state_yaml
  lock: false"
        fi
        ;;
    gcs)
        _gcs_bucket="$(_prompt "bucket" "")"
        _state_yaml="state:
  backend: gcs
  bucket: $_gcs_bucket"
        ;;
    azblob)
        _az_account="$(_prompt "storage_account" "")"
        _az_container="$(_prompt "container" "")"
        _state_yaml="state:
  backend: azblob
  storage_account: $_az_account
  container: $_az_container"
        ;;
    local) ;;
    *)
        fail "invalid state backend: $state_backend"
        ;;
    esac
    echo >&2

    # --- addons ---
    _addons_yaml=""
    _email=""
    _addons_dir="$ROCK8S_HOME/addons/modules"

    # build checklist dynamically from addon modules
    set --
    for _addon_dir in "$_addons_dir"/*/; do
        [ -d "$_addon_dir" ] || continue
        _name="$(basename "$_addon_dir")"
        _desc="$_name"
        if [ -f "$_addon_dir/description" ]; then
            _desc="$(cat "$_addon_dir/description")"
        fi
        _default="off"
        if [ -f "$_addon_dir/default_enabled" ]; then
            _default="on"
        fi
        set -- "$@" "$_name" "$_desc" "$_default"
    done
    _addon_selection=$(_dialog_checklist "Select addons to enable" "$@")

    # auto-enable dependencies
    if _has_addon "tempo" && ! _has_addon "rancher_logging"; then
        _addon_selection="$_addon_selection rancher_logging"
    fi
    if _has_addon "rancher_logging" && ! _has_addon "rancher_monitoring"; then
        _addon_selection="$_addon_selection rancher_monitoring"
    fi
    if _has_addon "rancher_istio" && ! _has_addon "rancher_monitoring"; then
        _addon_selection="$_addon_selection rancher_monitoring"
    fi

    # source each selected addon's init.sh for config, then build yaml
    for _addon in $_addon_selection; do
        _addon_yaml=""
        _addon_init="$_addons_dir/$_addon/init.sh"
        if [ -f "$_addon_init" ]; then
            . "$_addon_init"
        fi
        if [ -n "$_addon_yaml" ]; then
            _addons_yaml="$_addons_yaml
  $_addon:$_addon_yaml"
        else
            _addons_yaml="$_addons_yaml
  $_addon: {}"
        fi
    done

    # letsencrypt email (needed by cluster_issuer when no cloudflare)
    if _has_addon "cluster_issuer"; then
        _has_cloudflare="$(echo "$_addons_yaml" | grep -c 'cloudflare:' || true)"
        if [ "$_has_cloudflare" = "0" ]; then
            _email="$(_prompt "letsencrypt email" "")"
        fi
    fi

    # strip leading newline from addons block
    _addons_yaml="$(echo "$_addons_yaml" | sed '1{/^$/d}')"

    _write_config "$config_path"

    log "config written to $config_path"
}

_main "$@"
