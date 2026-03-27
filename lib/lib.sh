#!/bin/sh

set -e

RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

. "$ROCK8S_LIB_PATH/utils.sh"
. "$ROCK8S_LIB_PATH/format.sh"
. "$ROCK8S_LIB_PATH/network.sh"
. "$ROCK8S_LIB_PATH/secrets.sh"
. "$ROCK8S_LIB_PATH/config.sh"
. "$ROCK8S_LIB_PATH/state.sh"
. "$ROCK8S_LIB_PATH/k3s.sh"
. "$ROCK8S_LIB_PATH/master.sh"
. "$ROCK8S_LIB_PATH/worker.sh"

ensure_system
