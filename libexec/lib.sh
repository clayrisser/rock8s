#!/bin/sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

. "$ROCK8S_LIB_PATH/libexec/lib/utils.sh"
. "$ROCK8S_LIB_PATH/libexec/lib/format.sh"
. "$ROCK8S_LIB_PATH/libexec/lib/network.sh"
. "$ROCK8S_LIB_PATH/libexec/lib/validation.sh"
. "$ROCK8S_LIB_PATH/libexec/lib/output.sh"
. "$ROCK8S_LIB_PATH/libexec/lib/config.sh"
. "$ROCK8S_LIB_PATH/libexec/lib/kubespray.sh"

_ensure_system
