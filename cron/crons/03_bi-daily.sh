#!/bin/sh

exec 2>&1 > /tmp/03_bi-daily.log
date
set -e
set -x

sh "$CRONDIR/scripts/backup.sh"
date
