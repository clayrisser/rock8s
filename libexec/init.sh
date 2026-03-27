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
    if [ -n "$_default" ]; then
        printf "  %s [%s]: " "$_label" "$_default" >&2
    else
        printf "  %s: " "$_label" >&2
    fi
    read -r _value
    echo "${_value:-$_default}"
}

_prompt_yn() {
    _label="$1"
    _default="$2"
    if [ "$_YES" = "1" ]; then
        echo "$_default"
        return
    fi
    printf "  %s [%s]: " "$_label" "$_default" >&2
    read -r _value
    _value="${_value:-$_default}"
    case "$_value" in
    y | Y | yes | Yes | YES) echo "y" ;;
    *) echo "n" ;;
    esac
}

_provider_defaults() {
    case "$1" in
    hetzner)
        _def_location="nbg1"
        _def_image="debian-12"
        _def_master="cpx21"
        _def_worker="cpx31"
        ;;
    aws)
        _def_location="eu-central-1"
        _def_image="debian-12"
        _def_master="t3.medium"
        _def_worker="t3.large"
        ;;
    azure)
        _def_location="eastus"
        _def_image="debian-12"
        _def_master="Standard_B2s"
        _def_worker="Standard_B4ms"
        ;;
    gcp)
        _def_location="europe-west1"
        _def_image="debian-12"
        _def_master="e2-medium"
        _def_worker="e2-standard-2"
        ;;
    digitalocean)
        _def_location="fra1"
        _def_image="debian-12-x64"
        _def_master="s-2vcpu-4gb"
        _def_worker="s-4vcpu-8gb"
        ;;
    ovh)
        _def_location="GRA7"
        _def_image="Debian 12"
        _def_master="b2-7"
        _def_worker="b2-15"
        ;;
    vultr)
        _def_location="fra"
        _def_image="debian-12"
        _def_master="vc2-2c-4gb"
        _def_worker="vc2-4c-8gb"
        ;;
    libvirt)
        _def_location=""
        _def_image=""
        _def_master=""
        _def_worker=""
        ;;
    proxmox)
        _def_location=""
        _def_image=""
        _def_master="medium"
        _def_worker="large"
        ;;
    esac
}

_provider_credentials() {
    case "$1" in
    hetzner)
        _provider_yaml="  token: ref+env://HETZNER_TOKEN"
        ;;
    aws)
        _provider_yaml="  access_key: ref+env://AWS_ACCESS_KEY_ID
  secret_key: ref+env://AWS_SECRET_ACCESS_KEY"
        ;;
    azure)
        _provider_yaml="  subscription_id: ref+env://ARM_SUBSCRIPTION_ID
  client_id: ref+env://ARM_CLIENT_ID
  client_secret: ref+env://ARM_CLIENT_SECRET
  tenant_id: ref+env://ARM_TENANT_ID"
        ;;
    gcp)
        _cred_project="$(_prompt "project" "my-project")"
        _provider_yaml="  project: $_cred_project"
        ;;
    digitalocean)
        _provider_yaml="  token: ref+env://DIGITALOCEAN_TOKEN"
        ;;
    ovh)
        _cred_tenant="$(_prompt "tenant_name" "")"
        _cred_osuser="$(_prompt "openstack_user" "")"
        _provider_yaml="  application_key: ref+env://OVH_APPLICATION_KEY
  application_secret: ref+env://OVH_APPLICATION_SECRET
  consumer_key: ref+env://OVH_CONSUMER_KEY
  tenant_name: $_cred_tenant
  openstack_user: $_cred_osuser
  openstack_password: ref+env://OS_PASSWORD"
        ;;
    vultr)
        _provider_yaml="  api_key: ref+env://VULTR_API_KEY"
        ;;
    libvirt)
        _cred_uri="$(_prompt "uri" "qemu:///system")"
        _provider_yaml="  uri: $_cred_uri"
        ;;
    proxmox)
        _cred_endpoint="$(_prompt "endpoint URL" "https://10.0.0.2:8006/")"
        _cred_node="$(_prompt "node name" "pve")"
        _cred_insecure="$(_prompt "insecure TLS (true/false)" "true")"
        _provider_yaml="  endpoint: $_cred_endpoint
  api_token: ref+env://PROXMOX_VE_API_TOKEN
  node: $_cred_node
  insecure: $_cred_insecure"
        ;;
    esac
}

_dns_provider_yaml() {
    case "$1" in
    cloudflare)
        _dns_yaml="$_dns_yaml
    cloudflare:
      email: ref+env://CLOUDFLARE_EMAIL
      api_key: ref+env://CLOUDFLARE_API_KEY"
        ;;
    route53)
        _dns_yaml="$_dns_yaml
    route53:
      access_key: ref+env://AWS_ACCESS_KEY_ID
      secret_key: ref+env://AWS_SECRET_ACCESS_KEY
      region: us-east-1"
        ;;
    hetzner)
        _dns_yaml="$_dns_yaml
    hetzner:
      api_key: ref+env://HETZNER_DNS_TOKEN"
        ;;
    digitalocean)
        _dns_yaml="$_dns_yaml
    digitalocean:
      api_token: ref+env://DIGITALOCEAN_TOKEN"
        ;;
    powerdns)
        _dns_url="$(_prompt "powerdns api_url" "")"
        _dns_yaml="$_dns_yaml
    powerdns:
      api_url: $_dns_url
      api_key: ref+env://PDNS_API_KEY"
        ;;
    *)
        fail "unsupported dns provider: $1"
        ;;
    esac
}

_write_config() {
    _out="$1"
    {
        echo "provider:"
        echo "  type: $provider"
        printf '%s\n' "$_provider_yaml"
        if [ -n "$_def_location" ]; then
            echo ""
            echo "location: $location"
        fi
        if [ -n "$_def_image" ]; then
            echo "image: $image"
        fi
        echo ""
        echo "network:"
        echo "  entrypoint: $entrypoint"
        if [ -n "$gateway" ]; then
            echo "  gateway: $gateway"
        fi
        echo "  lan:"
        echo "    ipv4:"
        echo "      subnet: $lan_subnet"
        echo ""
        echo "masters:"
        echo "  - type: $master_type"
        echo "    count: $master_count"
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
    printf "${BLUE}provider${NC}\n" >&2
    provider="$(_prompt "type (hetzner, aws, azure, gcp, digitalocean, ovh, vultr, libvirt, proxmox)" "hetzner")"
    if ! echo "$provider" | grep -qE '^(hetzner|aws|azure|gcp|digitalocean|ovh|vultr|libvirt|proxmox)$'; then
        fail "invalid provider: $provider"
    fi
    _provider_defaults "$provider"
    _provider_credentials "$provider"
    echo >&2

    # --- infrastructure ---
    if [ -n "$_def_location" ]; then
        printf "${BLUE}infrastructure${NC}\n" >&2
        location="$(_prompt "location" "$_def_location")"
        image="$(_prompt "image" "$_def_image")"
        echo >&2
    fi

    # --- network ---
    printf "${BLUE}network${NC}\n" >&2
    entrypoint="$(_prompt "entrypoint (DNS hostname)" "cluster.example.com")"
    gateway="$(_prompt "gateway (leave empty for public IPs)" "")"
    lan_subnet="$(_prompt "LAN IPv4 subnet" "10.0.1.0/24")"
    echo >&2

    # --- nodes ---
    printf "${BLUE}master nodes${NC}\n" >&2
    master_type="$(_prompt "instance type" "$_def_master")"
    master_count="$(_prompt "count" "1")"
    echo >&2

    printf "${BLUE}worker nodes${NC}\n" >&2
    worker_type="$(_prompt "instance type" "$_def_worker")"
    worker_count="$(_prompt "count" "2")"
    echo >&2

    # --- state backend ---
    printf "${BLUE}state backend${NC}\n" >&2
    state_backend="$(_prompt "backend (local, s3, gcs, azblob)" "local")"
    _state_yaml=""
    case "$state_backend" in
    s3)
        _s3_bucket="$(_prompt "bucket" "")"
        _s3_region="$(_prompt "region" "us-east-1")"
        _s3_endpoint="$(_prompt "endpoint (leave empty for AWS)" "")"
        _state_yaml="state:
  backend: s3
  bucket: $_s3_bucket
  region: $_s3_region"
        if [ -n "$_s3_endpoint" ]; then
            _state_yaml="$_state_yaml
  endpoint: $_s3_endpoint"
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
    printf "${BLUE}addons${NC}\n" >&2
    _addons_yaml=""
    _email=""
    _kyverno="$(_prompt_yn "kyverno (policy engine)" "y")"
    _cluster_issuer="$(_prompt_yn "cluster_issuer (TLS certificates)" "y")"
    _reloader="$(_prompt_yn "reloader (auto-restart on config changes)" "n")"
    _rancher="$(_prompt_yn "rancher (cluster management UI)" "n")"
    _monitoring="$(_prompt_yn "rancher_monitoring (Prometheus/Grafana)" "n")"
    _logging="n"
    _istio="n"
    _tempo="n"
    if [ "$_monitoring" = "y" ]; then
        _logging="$(_prompt_yn "rancher_logging (log collection)" "n")"
        _istio="$(_prompt_yn "rancher_istio (service mesh)" "n")"
        if [ "$_logging" = "y" ]; then
            _tempo="$(_prompt_yn "tempo (distributed tracing)" "n")"
        fi
    fi
    _external_dns="$(_prompt_yn "external_dns (automatic DNS records)" "n")"
    _dns_yaml=""
    if [ "$_external_dns" = "y" ]; then
        _dns_default="cloudflare"
        case "$provider" in
        hetzner) _dns_default="hetzner" ;;
        aws) _dns_default="route53" ;;
        digitalocean) _dns_default="digitalocean" ;;
        esac
        _dns_pick="$(_prompt "dns provider (cloudflare, route53, hetzner, digitalocean, powerdns)" "$_dns_default")"
        _dns_provider_yaml "$_dns_pick"
        if [ "$_YES" != "1" ]; then
            while true; do
                _dns_more="$(_prompt_yn "add another dns provider" "n")"
                if [ "$_dns_more" != "y" ]; then
                    break
                fi
                _dns_pick="$(_prompt "dns provider (cloudflare, route53, hetzner, digitalocean, powerdns)" "")"
                _dns_provider_yaml "$_dns_pick"
            done
        fi
    fi
    if [ "$_cluster_issuer" = "y" ]; then
        _has_cloudflare="$(echo "$_dns_yaml" | grep -c 'cloudflare:' || true)"
        if [ "$_has_cloudflare" = "0" ]; then
            _email="$(_prompt "letsencrypt email" "")"
        fi
    fi
    _argocd="$(_prompt_yn "argocd (GitOps continuous delivery)" "n")"
    _flux="$(_prompt_yn "flux (GitOps toolkit)" "n")"
    _olm="$(_prompt_yn "olm (operator lifecycle manager)" "n")"
    _kanister="$(_prompt_yn "kanister (data backup/restore)" "n")"
    _openebs="$(_prompt_yn "openebs (container storage)" "n")"
    _longhorn="$(_prompt_yn "longhorn (distributed block storage)" "n")"
    _vault="$(_prompt_yn "vault (secrets management)" "n")"
    echo >&2

    # build addons yaml
    [ "$_kyverno" = "y" ] && _addons_yaml="$_addons_yaml  kyverno: {}"
    [ "$_cluster_issuer" = "y" ] && _addons_yaml="$_addons_yaml
  cluster_issuer: {}"
    [ "$_reloader" = "y" ] && _addons_yaml="$_addons_yaml
  reloader: {}"
    [ "$_rancher" = "y" ] && _addons_yaml="$_addons_yaml
  rancher:
    admin_password: ref+env://RANCHER_PASSWORD"
    [ "$_monitoring" = "y" ] && _addons_yaml="$_addons_yaml
  rancher_monitoring: {}"
    [ "$_logging" = "y" ] && _addons_yaml="$_addons_yaml
  rancher_logging: {}"
    [ "$_istio" = "y" ] && _addons_yaml="$_addons_yaml
  rancher_istio: {}"
    [ "$_tempo" = "y" ] && _addons_yaml="$_addons_yaml
  tempo: {}"
    if [ "$_external_dns" = "y" ] && [ -n "$_dns_yaml" ]; then
        _addons_yaml="$_addons_yaml
  external_dns:$_dns_yaml"
    fi
    [ "$_argocd" = "y" ] && _addons_yaml="$_addons_yaml
  argocd: {}"
    [ "$_flux" = "y" ] && _addons_yaml="$_addons_yaml
  flux: {}"
    [ "$_olm" = "y" ] && _addons_yaml="$_addons_yaml
  olm: {}"
    [ "$_kanister" = "y" ] && _addons_yaml="$_addons_yaml
  kanister: {}"
    [ "$_openebs" = "y" ] && _addons_yaml="$_addons_yaml
  openebs: {}"
    [ "$_longhorn" = "y" ] && _addons_yaml="$_addons_yaml
  longhorn: {}"
    [ "$_vault" = "y" ] && _addons_yaml="$_addons_yaml
  vault: {}"

    # strip leading newline from addons block
    _addons_yaml="$(echo "$_addons_yaml" | sed '1{/^$/d}')"

    _write_config "$config_path"

    log "config written to $config_path"
}

_main "$@"
