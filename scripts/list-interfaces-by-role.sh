#!/bin/sh

_INTERFACES_DATA="$(sh "$(dirname "$0")/list-interfaces.sh")"
_ALL_10G=""
_LINK_10G=""
_NO_LINK_10G=""
_OTHER_INTERFACES=""
for line in $(echo "$_INTERFACES_DATA"); do
    case "$line" in
    *=link:10G) _LINK_10G="$_LINK_10G ${line%%=*}"; _ALL_10G="$_ALL_10G ${line%%=*}" ;;
    *:10G) _NO_LINK_10G="$_NO_LINK_10G ${line%%=*}"; _ALL_10G="$_ALL_10G ${line%%=*}" ;;
    *) _OTHER_INTERFACES="$_OTHER_INTERFACES ${line%%=*}" ;;
    esac
done
_ALL_INTERFACES="$_LINK_10G $_NO_LINK_10G $_OTHER_INTERFACES"
set -- $_ALL_INTERFACES
_PRIVATE=$(eval echo \${$#})
set -- $_ALL_10G
if [ "$#" -ge 2 ]; then
    _UPLINK=$1
    _CEPH=$2
else
    set -- $_LINK_10G $_NO_LINK_10G
    _UPLINK=$1
    _CEPH=$2
fi
echo "uplink=$(echo "$_INTERFACES_DATA" | grep -E "^$_UPLINK=")"
echo "private=$(echo "$_INTERFACES_DATA" | grep -E "^$_PRIVATE=")"
echo "ceph=$(echo "$_INTERFACES_DATA" | grep -E "^$_CEPH=")"
