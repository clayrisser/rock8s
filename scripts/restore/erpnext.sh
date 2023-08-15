#!/bin/sh

set -e

DEPLOYMENT_NAME=$(kubectl get deployment -n "$NAMESPACE" | grep release-worker-d | cut -d' ' -f1)
if [ -z "$DEPLOYMENT_NAME" ]; then
    echo "no deployment found"
    exit 1
fi

POD_NAME=$(kubectl get pods -l app.kubernetes.io/instance=$DEPLOYMENT_NAME -n "$NAMESPACE" -o json | \
    jq -r '.items[] | select(.status.containerStatuses? and all(.status.containerStatuses[].ready?; . == true)) | .metadata.name' | \
    head -n 1)
if [ -z "$POD_NAME" ]; then
    echo "no pod found for deployment $DEPLOYMENT_NAME"
    exit 1
fi

SITE_BACKUPS=
for s in $(ls "$BACKUP_DIR" | grep site_config_backup.json); do
    SITE_BACKUPS="$(echo "$s" | sed 's|^[0-9]\+_[0-9]\+-\(.*\)-site_config_backup\.json$|\1|g')
$SITE_BACKUPS"
done
if [ -z "$SITE_BACKUPS" ]; then
    echo "no site backups found"
    exit 1
fi

SITES="$(kubectl exec -i "$POD_NAME" -n "$NAMESPACE" -- sh -c \
    "find ./sites -maxdepth 1 -name assets -prune -o -type d -print | sed 's|^\./sites/\?||g'" | sed '/^$/d')"
if [ -z "$SITES" ]; then
    echo "no sites found"
    exit 1
fi

MYSQL_ROOT_PASSWORD="$(kubectl get secret -n "$NAMESPACE" "${NAMESPACE}-release-mariadb" -o json | \
    jq -r '.data["mariadb-root-password"]' | base64 -d)"
if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
    echo "no mysql root password found"
    exit 1
fi

if [ "$SITE_MAP" = "" ]; then
    SITE_MAP="$(echo "$SITES" | head -n 1):$(echo "$SITE_BACKUPS" | head -n 1)"
fi
for sm in $SITE_MAP; do
    SITE="$(echo "$sm" | cut -d':' -f1)"
    BACKUP="$(echo "$sm" | cut -d':' -f2)"
    _SITE_PATH="/home/frappe/frappe-bench/sites/$SITE"
    if [ -z "$SITE" ] || [ -z "$BACKUP" ]; then
        echo "invalid site map: $sm"
        exit 1
    fi
    if ! echo "$SITES" | grep -q "$SITE"; then
        echo "site $SITE not found"
        exit 1
    fi
    if ! echo "$SITE_BACKUPS" | grep -q "$BACKUP"; then
        echo "backup $BACKUP not found"
        exit 1
    fi
    _PRIVATE_FILES_FILENAME=
    _FILES_FILENAME=
    _SITE_CONFIG_FILENAME=
    _BACKUP_FILENAME=
    for f in $(ls "$BACKUP_DIR" | grep "$BACKUP"); do
        if echo "$f" | grep -qE '\-database\.sql\.gz$'; then
            if [ ! -f "$BACKUP_DIR/$f" ]; then
                echo "backup file $BACKUP_DIR/$f not found"
                exit 1
            fi
            _BACKUP_FILENAME="$f"
        elif echo "$f" | grep -qE '\-private-files\.tar$'; then
            if [ ! -f "$BACKUP_DIR/$f" ]; then
                echo "backup file $BACKUP_DIR/$f not found"
                exit 1
            fi
            _PRIVATE_FILES_FILENAME="$f"
        elif echo "$f" | grep -qE '\-files\.tar$'; then
            if [ ! -f "$BACKUP_DIR/$f" ]; then
                echo "backup file $BACKUP_DIR/$f not found"
                exit 1
            fi
            _FILES_FILENAME="$f"
        elif echo "$f" | grep -qE '\-site_config_backup\.json$'; then
            if [ ! -f "$BACKUP_DIR/$f" ]; then
                echo "backup file $BACKUP_DIR/$f not found"
                exit 1
            fi
            _SITE_CONFIG_FILENAME="$f"
        fi
    done
    kubectl cp --retries="$RETRIES" "$BACKUP_DIR/$_BACKUP_FILENAME" "$NAMESPACE/$POD_NAME:$_SITE_PATH/private/backups/$_BACKUP_FILENAME"
    kubectl cp --retries="$RETRIES" "$BACKUP_DIR/$_PRIVATE_FILES_FILENAME" "$NAMESPACE/$POD_NAME:$_SITE_PATH/private/backups/$_PRIVATE_FILES_FILENAME"
    kubectl cp --retries="$RETRIES" "$BACKUP_DIR/$_FILES_FILENAME" "$NAMESPACE/$POD_NAME:$_SITE_PATH/private/backups/$_FILES_FILENAME"
    kubectl cp --retries="$RETRIES" "$BACKUP_DIR/$_SITE_CONFIG_FILENAME" "$NAMESPACE/$POD_NAME:$_SITE_PATH/private/backups/$_SITE_CONFIG_FILENAME"
    kubectl exec -i "$POD_NAME" -n "$NAMESPACE" -- sh -c \
        "echo \"$MYSQL_ROOT_PASSWORD\" | bench --site \"$SITE\" restore \"$_SITE_PATH/private/backups/$_BACKUP_FILENAME\" \
            --with-public-files \"$_SITE_PATH/private/backups/$_FILES_FILENAME\" \
            --with-private-files \"$_SITE_PATH/private/backups/$_PRIVATE_FILES_FILENAME\""
    rm -rf "$_SITE_PATH/private/backups/$_BACKUP_FILENAME" \
        "$_SITE_PATH/private/backups/$_PRIVATE_FILES_FILENAME" \
        "$_SITE_PATH/private/backups/$_FILES_FILENAME" \
        "$_SITE_PATH/private/backups/$_SITE_CONFIG_FILENAME"
    kubectl exec -i "$POD_NAME" -n "$NAMESPACE" -- sh -c \
        "bench --site \"$SITE\" migrate"
done
