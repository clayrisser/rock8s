#!/bin/sh

set -e

_AVAILABLE_REGISTRIES="
docker.io
ghcr.io
registry.gitlab.com
public.ecr.aws
quay.io"

_AVAILABLE_ADDONS="
ingress_nginx
ceph
s3
external_dns
flux
kanister
rancher
rancher_logging
olm
rancher_istio
rancher_monitoring
longhorn
reloader
argocd
karpenter
kyverno
crossplane
tempo
integration_operator
vault
openebs
cluster_issuer"

_DEFAULT_ENABLED_ADDONS="
ingress_nginx
external_dns
flux
kanister
olm
rancher_monitoring
reloader
argocd
karpenter
kyverno
integration_operator
s3
openebs
cluster_issuer"

_CEPH_MONITORS=""
_CEPH_ADMIN_ID=""
_CEPH_ADMIN_KEY=""
_CEPH_CLUSTER_ID=""
_CEPH_RBD_POOL="rbd"
_S3_ENDPOINT=""
_S3_ACCESS_KEY=""
_S3_SECRET_KEY=""
_PDNS_API_URL=""
_PDNS_API_KEY=""
_CLOUDFLARE_API_KEY=""
_CLOUDFLARE_EMAIL=""
_RANCHER_TOKEN=""
_RANCHER_HOSTNAME=""
_GIT_USERNAME=""
_GIT_PASSWORD=""
_GIT_REPO=""
_RETENTION_HOURS="168"
_KANISTER_BUCKET="${ROCK8S_CLUSTER}-kanister"

_is_addon_enabled() {
    for _SELECTED_ADDON in $_SELECTED_ADDONS; do
        if [ "$_SELECTED_ADDON" = "$1" ]; then
            return
        fi
    done
    return 1
}

_SELECTED_REGISTRIES="$(prompt_multiselect "Select registries to configure" "" $_AVAILABLE_REGISTRIES)"
_REGISTRIES=""
for _REGISTRY in $_SELECTED_REGISTRIES; do
    _REGISTRY_USERNAME="$(prompt_text "Enter username for $_REGISTRY" "" "" 1)"
    _REGISTRY_PASSWORD="$(prompt_password "Enter password for $_REGISTRY" "" 1)"
    if [ -n "$_REGISTRIES" ]; then
        _REGISTRIES="$_REGISTRIES
  $_REGISTRY:
    username: \"$_REGISTRY_USERNAME\"
    password: \"$_REGISTRY_PASSWORD\""
    else
        _REGISTRIES="  $_REGISTRY:
    username: \"$_REGISTRY_USERNAME\"
    password: \"$_REGISTRY_PASSWORD\""
    fi
done

if [ -z "$ADDONS" ]; then
    ADDONS="$(echo "$_DEFAULT_ENABLED_ADDONS" | tr '\n' ' ' | xargs)"
fi
export ADDONS
_AVAILABLE_ADDONS="$(echo "$_AVAILABLE_ADDONS" | tr '\n' ' ' | xargs)"
_SELECTED_ADDONS="$(prompt_multiselect "Select addons to enable" "ADDONS" $_AVAILABLE_ADDONS)"

_ADDONS_CONFIG=""
for _ADDON in $_AVAILABLE_ADDONS; do
    _ENABLED="false"
    for _SELECTED_ADDON in $_SELECTED_ADDONS; do
        if [ "$_ADDON" = "$_SELECTED_ADDON" ]; then
            _ENABLED="true"
            break
        fi
    done
    if [ -n "$_ADDONS_CONFIG" ]; then
        _ADDONS_CONFIG="$_ADDONS_CONFIG
  $_ADDON: $_ENABLED"
    else
        _ADDONS_CONFIG="  $_ADDON: $_ENABLED"
    fi
done

for _ADDON in $_SELECTED_ADDONS; do
    case $_ADDON in
        ceph)
            _CEPH_MONITORS="$(prompt_text "Enter ceph monitors" "CEPH_MONITORS" "" 1)"
            _CEPH_ADMIN_ID="$(prompt_text "Enter ceph admin id" "CEPH_ADMIN_ID" "" 1)"
            _CEPH_ADMIN_KEY="$(prompt_password "Enter ceph admin key" "CEPH_ADMIN_KEY" 1)"
            _CEPH_CLUSTER_ID="$(prompt_text "Enter ceph cluster id" "CEPH_CLUSTER_ID" "" 1)"
            _CEPH_RBD_POOL="$(prompt_text "Enter ceph rbd pool" "CEPH_RBD_POOL" "$_CEPH_RBD_POOL")"
            ;;
        s3)
            _S3_ENDPOINT="$(prompt_text "Enter s3 endpoint" "S3_ENDPOINT" "" 1)"
            _S3_ACCESS_KEY="$(prompt_text "Enter s3 access key" "S3_ACCESS_KEY" "" 1)"
            _S3_SECRET_KEY="$(prompt_password "Enter s3 secret key" "S3_SECRET_KEY" 1)"
            ;;
        external_dns)
            _DNS_PROVIDER="$(prompt_select "Select dns provider" "DNS_PROVIDER" "cloudflare" "powerdns" "cloudflare")"
            case $_DNS_PROVIDER in
                powerdns)
                    _PDNS_API_URL="$(prompt_text "Enter powerdns api url" "PDNS_API_URL" "" 1)"
                    _PDNS_API_KEY="$(prompt_password "Enter powerdns api key" "PDNS_API_KEY" 1)"
                    ;;
                cloudflare)
                    _CLOUDFLARE_EMAIL="$(prompt_text "Enter cloudflare email" "CLOUDFLARE_EMAIL" "" 1)"
                    _CLOUDFLARE_API_KEY="$(prompt_password "Enter cloudflare api key" "CLOUDFLARE_API_KEY" 1)"
                    ;;
            esac
            ;;
        rancher)
            _RANCHER_TOKEN="$(prompt_password "Enter rancher token" "RANCHER_TOKEN" 1)"
            _RANCHER_HOSTNAME="$(prompt_text "Enter rancher hostname" "RANCHER_HOSTNAME" "" 1)"
            ;;
        flux)
            _GIT_REPO="$(prompt_text "Enter git repository" "GIT_REPO" "" 1)"
            if ! (echo "$_GIT_REPO" | grep -q "gitlab.com" && echo "$_REGISTRIES" | grep -q "gitlab.com"); then
                _GIT_USERNAME="$(prompt_text "Enter git username" "GIT_USERNAME" "")"
                if [ -n "$_GIT_USERNAME" ]; then
                    _GIT_PASSWORD="$(prompt_password "Enter git password" "GIT_PASSWORD" 1)"
                else
                    _GIT_PASSWORD=""
                fi
            fi
            ;;
        tempo)
            _RETENTION_HOURS="$(prompt_text "Enter retention hours" "RETENTION_HOURS" "$_RETENTION_HOURS")"
            ;;
        kanister)
            _KANISTER_BUCKET="$(prompt_text "Enter kanister bucket name" "KANISTER_BUCKET" "$_KANISTER_BUCKET")"
            ;;
    esac
done

if [ -z "$_CLOUDFLARE_EMAIL" ]; then
    _EMAIL="$(prompt_text "Enter your email address" "EMAIL" "" 1)"
fi

_TENANT_CONFIG_FILE="$(get_tenant_config_file)"

if [ -n "$_REGISTRIES" ]; then
    cat <<EOF >> "$_TENANT_CONFIG_FILE"
registries:
$_REGISTRIES
EOF
else
    cat <<EOF >> "$_TENANT_CONFIG_FILE"
registries:
EOF
fi

cat <<EOF >> "$_TENANT_CONFIG_FILE"
addons:
$_ADDONS_CONFIG
  email: $_EMAIL
EOF

if _is_addon_enabled "kanister"; then
    cat <<EOF >> "$_TENANT_CONFIG_FILE"
  kanister_bucket: $_KANISTER_BUCKET
EOF
fi

if _is_addon_enabled "ceph"; then
    cat <<EOF >> "$_TENANT_CONFIG_FILE"
  ceph_monitors:
$(echo "$_CEPH_MONITORS" | tr ',' ' ' | tr -s ' ' '\n' | sed '/^$/d' | sed 's/^/    - /')
  ceph_admin_id: $_CEPH_ADMIN_ID
  ceph_admin_key: $_CEPH_ADMIN_KEY
  ceph_cluster_id: $_CEPH_CLUSTER_ID
  ceph_rbd_pool: $_CEPH_RBD_POOL
EOF
fi

if _is_addon_enabled "external_dns" && [ -n "$_PDNS_API_URL" ]; then
    cat <<EOF >> "$_TENANT_CONFIG_FILE"
  pdns_api_url: $_PDNS_API_URL
  pdns_api_key: $_PDNS_API_KEY
EOF
fi

if _is_addon_enabled "external_dns" && [ -n "$_CLOUDFLARE_API_KEY" ]; then
    cat <<EOF >> "$_TENANT_CONFIG_FILE"
  cloudflare_api_key: $_CLOUDFLARE_API_KEY
  cloudflare_email: $_CLOUDFLARE_EMAIL
EOF
fi

if _is_addon_enabled "flux"; then
    cat <<EOF >> "$_TENANT_CONFIG_FILE"
  git_username: $_GIT_USERNAME
  git_password: $_GIT_PASSWORD
  git_repo: $_GIT_REPO
EOF
fi

if _is_addon_enabled "s3"; then
    cat <<EOF >> "$_TENANT_CONFIG_FILE"
  s3_endpoint: $_S3_ENDPOINT
  s3_access_key: $_S3_ACCESS_KEY
  s3_secret_key: $_S3_SECRET_KEY
EOF
fi

if _is_addon_enabled "rancher"; then
    if [ -n "$_RANCHER_TOKEN" ]; then
        cat <<EOF >> "$_TENANT_CONFIG_FILE"
  rancher_token: $_RANCHER_TOKEN
  rancher_hostname: $_RANCHER_HOSTNAME
EOF
    fi
fi

if _is_addon_enabled "tempo"; then
    cat <<EOF >> "$_TENANT_CONFIG_FILE"
  retention_hours: $_RETENTION_HOURS
EOF
fi
