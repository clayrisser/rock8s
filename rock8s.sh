#!/bin/sh

export _TMP_PATH="${XDG_RUNTIME_DIR:-$([ -d "/run/user/$(id -u $USER)" ] && echo "/run/user/$(id -u $USER)" || echo ${TMP:-${TEMP:-/tmp}})}/cody/wizard/$$"
export _STATE_PATH="${XDG_STATE_HOME:-$HOME/.local/state}/dotstow"

main() {
    if [ "$_COMMAND" = "backup" ]; then
        _backup $@
    elif [ "$_COMMAND" = "restore" ]; then
        _restore $@
    fi
}

_backup() {
    exec sh "./scripts/backup.sh" $@
}

_restore() {
    exec sh "./scripts/restore.sh" $@
}

if ! test $# -gt 0; then
    set -- "-h"
fi

while test $# -gt 0; do
    case "$1" in
        -h|--help)
            echo "rock8s - operate a rock8s cluster"
            echo " "
            echo "rock8s [options] command"
            echo " "
            echo "options:"
            echo "    -h, --help      show brief help"
            echo " "
            echo "commands:"
            echo "    b, backup       backup data"
            echo "    r, restore      restore data"
            exit 0
        ;;
        -*)
            echo "invalid option $1" 1>&2
            exit 1
        ;;
        *)
            break
        ;;
    esac
done

case "$1" in
    b|backup)
        shift
        export _COMMAND=backup
    ;;
    r|restore)
        shift
        export _COMMAND=restore
    ;;
    *)
        echo "invalid command $1" 1>&2
        exit 1
    ;;
esac

main $@
