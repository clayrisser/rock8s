#!/bin/sh

STATEFULSET_NAME=$(kubectl get statefulset -n "$NAMESPACE" | grep release | cut -d' ' -f1)
POD_NAME=$(kubectl get pods -l app.kubernetes.io/instance=$STATEFULSET_NAME -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}')
SECRET_RESOURCE="
$(kubectl get secret openldap -o json -n "$NAMESPACE")
"
RELEASE_NAME=$(echo $STATEFULSET_NAME | sed 's|-release$||g')

LDAP_ROOT=$(kubectl get configmap $RELEASE_NAME-release-env -o json -n "$NAMESPACE" | jq -r '.data.LDAP_ROOT')
BIND_ID="cn=admin,$LDAP_ROOT"
BIND_PASSWORD="$(echo "$SECRET_RESOURCE" | jq -r '.data.LDAP_ADMIN_PASSWORD' | openssl base64 -d)"

kubectl exec -i "$POD_NAME" -n "$NAMESPACE" -- sh -c \
    "ldapsearch -x -D \"$BIND_ID\" -w \"$BIND_PASSWORD\" -b \"$LDAP_ROOT\" -H ldap://localhost -LLL" > "$BACKUP_DIR/dump.ldif"
