#!/bin/sh

AVAILABLE_LOCATIONS="nbg1 fsn1 hel1 ash dc1"
AVAILABLE_SERVER_TYPES="cpx11 cpx21 cpx31 cpx41 cpx51 cax11 cax21 cax31 cax41 ccx13 ccx23 ccx33 ccx43 ccx53 ccx63 cx22 cx32 cx42 cx52"

DEFAULT_LOCATION="nbg1"
DEFAULT_MASTER_COUNT="1"
DEFAULT_NETWORK="private"
DEFAULT_SERVER_TYPE="cx22"
DEFAULT_WORKER_COUNT="2"

: "${LOCATION:=$DEFAULT_LOCATION}"
: "${NETWORK:=$DEFAULT_NETWORK}"
