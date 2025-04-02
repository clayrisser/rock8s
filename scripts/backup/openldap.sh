#!/bin/sh

set -e

ldif_postprocess() {
    python3 -c "
import base64
import sys
processing_password = False
password_lines = []
for line in sys.stdin:
    stripped_line = line.strip()
    if processing_password:
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
        elif stripped_line.lower().startswith('userpassword:: '):
            sys.stdout.write(line)
        else:
            sys.stdout.write(line)
if processing_password:
    password = ''.join(password_lines)
    base64_password = base64.b64encode(password.encode('utf-8')).decode('utf-8')
    sys.stdout.write('userPassword:: ' + base64_password + '\n')
"
}

STATEFULSET_NAME=$(kubectl get statefulset -n "$NAMESPACE" | grep release | cut -d' ' -f1)
if [ -z "$STATEFULSET_NAME" ]; then
    echo "no statefulset found" >&2
    exit 1
fi
POD_NAME=$(kubectl get pods -l app.kubernetes.io/instance=$STATEFULSET_NAME -n "$NAMESPACE" --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')
if [ -z "$POD_NAME" ]; then
    echo "no running pod found for statefulset $STATEFULSET_NAME" >&2
    exit 1
fi
SECRET_RESOURCE="
$(kubectl get secret openldap -o json -n "$NAMESPACE")
"
RELEASE_NAME=$(echo $STATEFULSET_NAME | sed 's|-release$||g')

LDAP_ROOT=$(kubectl get configmap $RELEASE_NAME-release-env -o json -n "$NAMESPACE" | jq -r '.data.LDAP_ROOT')
if [ -z "$LDAP_ROOT" ]; then
    echo "no ldap root found" >&2
    exit 1
fi

kubectl exec -i "$POD_NAME" -n "$NAMESPACE" -- sh -c \
    "ldapsearch -Y EXTERNAL -H ldapi:/// -b $LDAP_ROOT" | \
    ldif_postprocess > "$BACKUP_DIR/dump.ldif"
