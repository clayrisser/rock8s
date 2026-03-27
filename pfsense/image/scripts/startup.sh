#!/bin/sh
# PROVIDE: startup
# REQUIRE: config
# BEFORE: netif

. /etc/rc.subr

name="startup"
rcvar="startup_enable"
command="/usr/local/libexec/initialize"

load_rc_config $name
: ${startup_enable:="YES"}
run_rc_command "$1"
