#!/bin/sh

EOF=EOF
exec cat <<EOF | sh
cat <<EOF
$(cat $1 |
    sed 's|\\|\\\\|g' |
    sed 's|`|\\`|g' |
    sed 's|\$|\\\$|g' |
    sed "s|${OPEN:-<%}|\`echo |g" |
    sed "s|${CLOSE:-%>}| 2>/dev/null \`|g")
$EOF
EOF
