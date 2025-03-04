#!/bin/sh

PROVIDER_OUTPUT="$DATA_DIR/$PROVIDER/.env.output"
if [ -f "$PROVIDER_OUTPUT" ]; then
    . "$PROVIDER_OUTPUT"
fi
KUBESPRAY_OUTPUT="$DATA_DIR/kubespray/.env.output"
if [ -f "$KUBESPRAY_OUTPUT" ]; then
    . "$KUBESPRAY_OUTPUT"
fi
if [ "$EMAIL" = "" ] && [ "$CLOUDFLARE_EMAIL" != "" ]; then
    EMAIL="$CLOUDFLARE_EMAIL"
fi
if [ "$RANCHER_HOSTNAME" = "" ] && [ "$ENTRYPOINT" != "" ]; then
    RANCHER_HOSTNAME="$ENTRYPOINT"
fi

if [ "$EMAIL" = "" ]; then
    echo "missing EMAIL" >&2
    exit 1
fi
if [ "$ENTRYPOINT" = "" ]; then
    echo "missing ENTRYPOINT" >&2
    exit 1
fi
if ! host "$ENTRYPOINT" >/dev/null 2>&1; then
    echo "entrypoint $ENTRYPOINT does not resolve" >&2
    exit 1
fi

export TF_VAR_cluster_name="$CLUSTER_NAME"
export TF_VAR_email="$EMAIL"
export TF_VAR_entrypoint="$ENTRYPOINT"
export TF_VAR_argocd="$ARGOCD"
export TF_VAR_cluster_issuer="$CLUSTER_ISSUER"
export TF_VAR_crossplane="$CROSSPLANE"
export TF_VAR_external_dns="$EXTERNAL_DNS"
export TF_VAR_flux="$FLUX"
export TF_VAR_ingress_nginx="$INGRESS_NGINX"
export TF_VAR_integration_operator="$INTEGRATION_OPERATOR"
export TF_VAR_karpenter="$KARPENTER"
export TF_VAR_kyverno="$KYVERNO"
export TF_VAR_longhorn="$LONGHORN"
export TF_VAR_olm="$OLM"
export TF_VAR_reloader="$RELOADER"
export TF_VAR_tempo="$TEMPO"
export TF_VAR_thanos="$THANOS"
export TF_VAR_vault="$VAULT"
export TF_VAR_ceph="$CEPH"
export TF_VAR_ceph_admin_id="$CEPH_ADMIN_ID"
export TF_VAR_ceph_admin_key="$CEPH_ADMIN_KEY"
export TF_VAR_ceph_cluster_id="$CEPH_CLUSTER_ID"
export TF_VAR_ceph_fs_name="$CEPH_FS_NAME"
export TF_VAR_ceph_monitors="$CEPH_MONITORS"
export TF_VAR_ceph_rbd_pool="$CEPH_RBD_POOL"
export TF_VAR_cloudflare_api_key="$CLOUDFLARE_API_KEY"
export TF_VAR_cloudflare_email="$CLOUDFLARE_EMAIL"
export TF_VAR_pdns_api_url="$PDNS_API_URL"
export TF_VAR_pdns_api_key="$PDNS_API_KEY"
export TF_VAR_s3="$S3"
export TF_VAR_s3_endpoint="$S3_ENDPOINT"
export TF_VAR_s3_access_key="$S3_ACCESS_KEY"
export TF_VAR_s3_secret_key="$S3_SECRET_KEY"
export TF_VAR_kanister="$KANISTER"
export TF_VAR_kanister_bucket="$KANISTER_BUCKET"
export TF_VAR_rancher="$RANCHER"
export TF_VAR_rancher_hostname="$RANCHER_HOSTNAME"
export TF_VAR_rancher_istio="$RANCHER_ISTIO"
export TF_VAR_rancher_logging="$RANCHER_LOGGING"
export TF_VAR_rancher_monitoring="$RANCHER_MONITORING"
export TF_VAR_rancher_token="$RANCHER_TOKEN"
export TF_VAR_ingress_ports="$INGRESS_PORTS"
export TF_VAR_retention_hours="$RETENTION_HOURS"
