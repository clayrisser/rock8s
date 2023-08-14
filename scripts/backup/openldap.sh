#!/bin/sh

set -e

STATEFULSET_NAME=$(kubectl get statefulset -n "$NAMESPACE" | grep release | cut -d' ' -f1)
if [ -z "$STATEFULSET_NAME" ]; then
    echo "no statefulset found"
    exit 1
fi
POD_NAME=$(kubectl get pods -l app.kubernetes.io/instance=$STATEFULSET_NAME -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}')
if [ -z "$POD_NAME" ]; then
    echo "no pod found"
    exit 1
fi
SECRET_RESOURCE="
$(kubectl get secret openldap -o json -n "$NAMESPACE")
"
RELEASE_NAME=$(echo $STATEFULSET_NAME | sed 's|-release$||g')

LDAP_ROOT=$(kubectl get configmap $RELEASE_NAME-release-env -o json -n "$NAMESPACE" | jq -r '.data.LDAP_ROOT')
if [ -z "$LDAP_ROOT" ]; then
    echo "no ldap root found"
    exit 1
fi
BIND_ID="cn=admin,$LDAP_ROOT"
BIND_PASSWORD="$(echo "$SECRET_RESOURCE" | jq -r '.data.LDAP_ADMIN_PASSWORD' | openssl base64 -d)"
if [ -z "$BIND_PASSWORD" ]; then
    echo "no bind password found"
    exit 1
fi

kubectl exec -i "$POD_NAME" -n "$NAMESPACE" -- sh -c \
    "ldapsearch -x -D \"$BIND_ID\" -w \"$BIND_PASSWORD\" -b \"$LDAP_ROOT\" -H ldap://localhost -LLL" > "$BACKUP_DIR/dump.ldif"
