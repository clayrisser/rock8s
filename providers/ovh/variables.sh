#!/bin/sh

set -e

export TF_VAR_ovh_application_key="$(get_config '.provider.application_key // ""' "$OVH_APPLICATION_KEY")"
export TF_VAR_ovh_application_secret="$(get_config '.provider.application_secret // ""' "$OVH_APPLICATION_SECRET")"
export TF_VAR_ovh_consumer_key="$(get_config '.provider.consumer_key // ""' "$OVH_CONSUMER_KEY")"
export TF_VAR_ovh_tenant_name="$(get_config '.provider.tenant_name // ""' "$OS_TENANT_NAME")"
export TF_VAR_ovh_openstack_user="$(get_config '.provider.openstack_user // ""' "$OS_USERNAME")"
export TF_VAR_ovh_openstack_password="$(get_config '.provider.openstack_password // ""' "$OS_PASSWORD")"

_missing=""
[ -z "$TF_VAR_ovh_application_key" ] && _missing="$_missing ovh_application_key"
[ -z "$TF_VAR_ovh_application_secret" ] && _missing="$_missing ovh_application_secret"
[ -z "$TF_VAR_ovh_consumer_key" ] && _missing="$_missing ovh_consumer_key"
[ -z "$TF_VAR_ovh_tenant_name" ] && _missing="$_missing ovh_tenant_name"
[ -z "$TF_VAR_ovh_openstack_user" ] && _missing="$_missing ovh_openstack_user"
[ -z "$TF_VAR_ovh_openstack_password" ] && _missing="$_missing ovh_openstack_password"
if [ -n "$_missing" ]; then
    fail "missing OVH / OpenStack credentials:$_missing (set provider.* in config or OVH_* / OS_* env vars)"
fi
