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
POD_NAME=$(kubectl get pods -l app.kubernetes.io/instance=$STATEFULSET_NAME -n "$NAMESPACE" --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')
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
try "kubectl exec $POD_NAME -n $NAMESPACE -- sh -c \"rm -rf $_BACKUP_TMP* || true\""
try "kubectl exec $POD_NAME -n $NAMESPACE -- sh -c \"mkdir -p $_BACKUP_TMP\""
try "kubectl exec $POD_NAME -n $NAMESPACE -- sh -c \"ldapsearch -Y EXTERNAL -H ldapi:/// -b $LDAP_ROOT > $_BACKUP_TMP/dump.ldif\""
try "kubectl exec $POD_NAME -n $NAMESPACE -- sh -c \"cd $_BACKUP_TMP && tar czf ${_BACKUP_TMP}.tar.gz dump.ldif\""
SIZE=$(kubectl exec "$POD_NAME" -n "$NAMESPACE" -- sh -c "wc -c < ${_BACKUP_TMP}.tar.gz")
mkdir -p "$BACKUP_DIR"
cd "$BACKUP_DIR"
rm -f dump.ldif
try "kubectl cp --retries=$RETRIES $NAMESPACE/$POD_NAME:${_BACKUP_TMP}.tar.gz ./openldap.tar.gz" >/dev/null 2>&1 &
_START_TIME=$(date +%s)
_LAST_SIZE=0
while [ ! -f ./openldap.tar.gz ] || [ "$(wc -c < ./openldap.tar.gz)" -lt "$SIZE" ]; do
    [ -f ./openldap.tar.gz ] && _CURRENT_SIZE=$(wc -c < ./openldap.tar.gz) || _CURRENT_SIZE=0
    _ELAPSED=$(($(date +%s) - _START_TIME))
    [ $_ELAPSED -eq 0 ] && _RATE=0 || _RATE=$((_CURRENT_SIZE / _ELAPSED))
    _PERCENT=$((_CURRENT_SIZE * 100 / SIZE))
    show_progress "$NAMESPACE/openldap" $_CURRENT_SIZE $SIZE $_RATE $_PERCENT
    _LAST_SIZE=$_CURRENT_SIZE
    sleep 1
done
wait
if [ ! -f ./openldap.tar.gz ] || [ "$(wc -c < ./openldap.tar.gz)" -ne "$SIZE" ]; then
    rm -f openldap.tar.gz
    fail "failed to download openldap backup"
fi
printf "\033[2K\r%s %s %s\n" "$NAMESPACE/openldap" "████████████████████" "$(format_size $SIZE)" >&2
try "tar xzf openldap.tar.gz"
cat dump.ldif | ldif_postprocess > dump.ldif.tmp
mv dump.ldif.tmp dump.ldif
rm -f openldap.tar.gz
try "kubectl exec $POD_NAME -n $NAMESPACE -- sh -c \"rm -rf $_BACKUP_TMP*\""
