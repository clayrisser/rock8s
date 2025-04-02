#!/bin/sh

set -e

ldif_preprocess() {
    python3 -c "
import base64
import sys
processing_password = False
password_lines = []
for line in sys.stdin:
    stripped_line = line.strip()
    if stripped_line.startswith('dn: '):
        sys.stdout.write(line)
        sys.stdout.write('changetype: add\n')
    elif processing_password:
        if line.startswith(' '):
            password_lines.append(stripped_line)
        else:
            password = ''.join(password_lines)
            base64_password = base64.b64encode(password.encode('utf-8')).decode('utf-8')
            sys.stdout.write('userPassword:: ' + base64_password + '\n')
            processing_password = False
            password_lines = []
            sys.stdout.write(line)
    else:
        if stripped_line.lower().startswith('userpassword: '):
            processing_password = True
            password_lines = [stripped_line.split(' ', 1)[1]]
        else:
            sys.stdout.write(line)
if processing_password:
    password = ''.join(password_lines)
    base64_password = base64.b64encode(password.encode('utf-8')).decode('utf-8')
    sys.stdout.write('userPassword:: ' + base64_password + '\n')
    processing_password = False
"
}

STATEFULSET_NAME=$(kubectl get statefulset -n "$NAMESPACE" | grep release | cut -d' ' -f1)
POD_NAME=$(kubectl get pods -l app.kubernetes.io/instance=$STATEFULSET_NAME -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}')
SECRET_RESOURCE="
$(kubectl get secret openldap -o json -n "$NAMESPACE")
"
RELEASE_NAME=$(echo $STATEFULSET_NAME | sed 's|-release$||g')

LDAP_ROOT=$(kubectl get configmap $RELEASE_NAME-release-env -o json -n "$NAMESPACE" | jq -r '.data.LDAP_ROOT')
if [ -z "$LDAP_ROOT" ]; then
    echo "no ldap root found" >&2
    exit 1
fi

DUMP_LDIF="${BACKUP_DIR}/dump.ldif"
if [ -z "$OLD_LDAP_ROOT" ]; then
    OLD_LDAP_ROOT="$LDAP_ROOT"
fi
cat "$DUMP_LDIF" | \
    sed "s|$OLD_LDAP_ROOT|$LDAP_ROOT|g" | \
    ldif_preprocess | \
    kubectl exec -i "$POD_NAME" -n "$NAMESPACE" -- sh -c \
    "ldapmodify -Y EXTERNAL -H ldapi:/// -c" || true
