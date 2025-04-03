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
    fail "no statefulset found"
fi
POD_NAME="$(wait_for_pod "$NAMESPACE" "app.kubernetes.io/instance=$STATEFULSET_NAME" "")"
if [ -z "$POD_NAME" ]; then
    fail "no running pod found for statefulset $STATEFULSET_NAME"
fi
RELEASE_NAME=$(echo $STATEFULSET_NAME | sed 's|-release$||g')
LDAP_ROOT=$(kubectl get configmap $RELEASE_NAME-release-env -o json -n "$NAMESPACE" | jq -r '.data.LDAP_ROOT')
if [ -z "$LDAP_ROOT" ]; then
    fail "no ldap root found"
fi
log "backing up openldap database $NAMESPACE/openldap"
_BACKUP_TMP="/tmp/.rock8s_backup"
backup_create_temp "$POD_NAME" "$NAMESPACE" "" "$_BACKUP_TMP"
try "kubectl exec $POD_NAME -n $NAMESPACE -- sh -c \"ldapsearch -Y EXTERNAL -H ldapi:/// -b $LDAP_ROOT > $_BACKUP_TMP/dump.ldif\""
backup_compress_temp "$POD_NAME" "$NAMESPACE" "" "$_BACKUP_TMP" "dump.ldif"
mkdir -p "$BACKUP_DIR"
cd "$BACKUP_DIR"
backup_download_with_progress "$POD_NAME" "$NAMESPACE" "" "${_BACKUP_TMP}.tar.gz" "./openldap.tar.gz" "$NAMESPACE/openldap"
backup_extract_archive "./openldap.tar.gz" "."
cat dump.ldif | ldif_postprocess > dump.ldif.tmp
mv dump.ldif.tmp dump.ldif
backup_cleanup_temp "$POD_NAME" "$NAMESPACE" "" "$_BACKUP_TMP"
