#!/bin/sh

_INTERFACE_DATA=$(sh "$(dirname "$0")/list-interfaces.sh")
_ALL_10G=""
_LINK_10G=""
_NO_LINK_10G=""
_OTHER_INTERFACES=""
for line in $(echo "$_INTERFACE_DATA"); do
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
echo "$_UPLINK=uplink:$($interface_data | grep -E "^$_UPLINK=" | cut -d= -f2)"
echo "$_CEPH=ceph:$($interface_data | grep -E "^$_CEPH=" | cut -d= -f2)"
echo "$_PRIVATE=private:$($interface_data | grep -E "^$_PRIVATE=" | cut -d= -f2)"
