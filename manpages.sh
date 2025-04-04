#!/bin/sh

set -e

_MAN_DIR="man"
_MAN1_DIR="${_MAN_DIR}/man1"
_BUILD_DIR=".build"
_MAIN_CMD="rock8s"
_SUBCOMMANDS="nodes cluster pfsense completion"
_NODES_SUBCOMMANDS="ls create destroy ssh pubkey apply"
_CLUSTER_SUBCOMMANDS="configure setup bootstrap login reset use apply install upgrade node scale"
_PFSENSE_SUBCOMMANDS="configure list apply destroy publish"
_COMPLETION_SUBCOMMANDS="bash zsh"
_NODE_SUBCOMMANDS="rm"

mkdir -p "$_MAN1_DIR" >/dev/null 2>&1
mkdir -p "$_BUILD_DIR" >/dev/null 2>&1

extract_help_text() {
    _FILE="$1"
    _FUNC_NAME="$2"
    _OUTPUT_FILE="$3"
    if [ -f "${_FILE}" ]; then
        sed -n "/${_FUNC_NAME}() {/,/^}/p" "${_FILE}" |
            sed -n '/cat <<EOF/,/EOF/p' |
            sed '1d;$d' > "${_OUTPUT_FILE}"
        return 0
    else
        return 1
    fi
}

generate_main_manpage() {
    printf '.TH ROCK8S 1 "%s" "rock8s" "User Commands"\n' "$(date +'%B %Y')" > "${_MAN1_DIR}/${_MAIN_CMD}.1"
    _HELP_FILE="${_BUILD_DIR}/rock8s-help-main.txt"
    extract_help_text "rock8s.sh" "_help" "${_HELP_FILE}"
    if [ -s "${_HELP_FILE}" ]; then
        cat "${_HELP_FILE}" | \
            sed -e 's/^NAME$/.SH NAME/' | \
            sed -e 's/^SYNOPSIS$/.SH SYNOPSIS/' | \
            sed -e 's/^DESCRIPTION$/.SH DESCRIPTION/' | \
            sed -e 's/^OPTIONS$/.SH OPTIONS/' | \
            sed -e 's/^COMMANDS$/.SH COMMANDS/' | \
            sed -e 's/^EXAMPLE$/.SH EXAMPLES/' | \
            sed -e 's/^SEE ALSO$/.SH SEE ALSO/' | \
            sed -e 's/rock8s \([a-z-]*\) --help/rock8s-\1(1)/' >> "${_MAN1_DIR}/${_MAIN_CMD}.1"
    else
        printf '.SH NAME\n%s \\- universal kubernetes cluster\n' "${_MAIN_CMD}" >> "${_MAN1_DIR}/${_MAIN_CMD}.1"
        printf '.SH SYNOPSIS\n       %s [options]\n\n.SH DESCRIPTION\n       Universal kubernetes cluster\n' "${_MAIN_CMD}" >> "${_MAN1_DIR}/${_MAIN_CMD}.1"
    fi
}

generate_subcommand_manpage() {
    _CMD="$1"
    _MAIN_CMD_UPPER=$(echo "${_MAIN_CMD}" | tr '[:lower:]' '[:upper:]') 2> /dev/null
    _CMD_UPPER=$(echo "${_CMD}" | tr '[:lower:]' '[:upper:]') 2> /dev/null
    printf '.TH %s-%s 1 "%s" "rock8s" "User Commands"\n' "${_MAIN_CMD_UPPER}" "${_CMD_UPPER}" "$(date +'%B %Y')" > "${_MAN1_DIR}/${_MAIN_CMD}-${_CMD}.1"
    _HELP_FILE="${_BUILD_DIR}/rock8s-help-${_CMD}.txt"
    _SUBCMD_FILE="libexec/${_CMD}.sh"
    if [ -f "${_SUBCMD_FILE}" ]; then
        extract_help_text "${_SUBCMD_FILE}" "_help" "${_HELP_FILE}"
    fi
    if [ -s "${_HELP_FILE}" ]; then
        cat "${_HELP_FILE}" | \
            sed -e 's/^NAME$/.SH NAME/' | \
            sed -e 's/^SYNOPSIS$/.SH SYNOPSIS/' | \
            sed -e 's/^DESCRIPTION$/.SH DESCRIPTION/' | \
            sed -e 's/^OPTIONS$/.SH OPTIONS/' | \
            sed -e 's/^COMMANDS$/.SH COMMANDS/' | \
            sed -e 's/^EXAMPLE$/.SH EXAMPLES/' | \
            sed -e 's/^SEE ALSO$/.SH SEE ALSO/' | \
            sed -e 's/rock8s \([a-z-]*\) --help/rock8s-\1(1)/' | \
            sed -e "s/rock8s ${_CMD} \([a-z-]*\) --help/rock8s-${_CMD}-\1(1)/" >> "${_MAN1_DIR}/${_MAIN_CMD}-${_CMD}.1"
    else
        printf '.SH NAME\n%s-%s \\- %s %s command\n' "${_MAIN_CMD}" "${_CMD}" "${_MAIN_CMD}" "${_CMD}" >> "${_MAN1_DIR}/${_MAIN_CMD}-${_CMD}.1"
        printf '.SH SYNOPSIS\n       %s %s [options]\n\n.SH DESCRIPTION\n       %s command\n\n.SH SEE ALSO\n       %s(1)\n' \
            "${_MAIN_CMD}" "${_CMD}" "${_CMD}" "${_MAIN_CMD}" >> "${_MAN1_DIR}/${_MAIN_CMD}-${_CMD}.1"
    fi
}

generate_sub_subcommand_manpage() {
    _CMD="$1"
    _SUBCMD="$2"
    _MAIN_CMD_UPPER=$(echo "${_MAIN_CMD}" | tr '[:lower:]' '[:upper:]') 2> /dev/null
    _CMD_UPPER=$(echo "${_CMD}" | tr '[:lower:]' '[:upper:]') 2> /dev/null
    _SUBCMD_UPPER=$(echo "${_SUBCMD}" | tr '[:lower:]' '[:upper:]') 2> /dev/null
    printf '.TH %s-%s-%s 1 "%s" "rock8s" "User Commands"\n' "${_MAIN_CMD_UPPER}" "${_CMD_UPPER}" "${_SUBCMD_UPPER}" "$(date +'%B %Y')" > "${_MAN1_DIR}/${_MAIN_CMD}-${_CMD}-${_SUBCMD}.1"
    _HELP_FILE="${_BUILD_DIR}/rock8s-help-${_CMD}-${_SUBCMD}.txt"
    _SUBCMD_FILE="libexec/${_CMD}/${_SUBCMD}.sh"
    if [ -f "${_SUBCMD_FILE}" ]; then
        extract_help_text "${_SUBCMD_FILE}" "_help" "${_HELP_FILE}"
    fi
    if [ -s "${_HELP_FILE}" ]; then
        cat "${_HELP_FILE}" | \
            sed -e 's/^NAME$/.SH NAME/' | \
            sed -e 's/^SYNOPSIS$/.SH SYNOPSIS/' | \
            sed -e 's/^DESCRIPTION$/.SH DESCRIPTION/' | \
            sed -e 's/^OPTIONS$/.SH OPTIONS/' | \
            sed -e 's/^COMMANDS$/.SH COMMANDS/' | \
            sed -e 's/^EXAMPLE$/.SH EXAMPLES/' | \
            sed -e 's/^SEE ALSO$/.SH SEE ALSO/' | \
            sed -e "s/rock8s ${_CMD} ${_SUBCMD} \([a-z-]*\) --help/rock8s-${_CMD}-${_SUBCMD}-\1(1)/" | \
            sed -e "s/rock8s ${_CMD} \([a-z-]*\) --help/rock8s-${_CMD}-\1(1)/" | \
            sed -e 's/rock8s \([a-z-]*\) --help/rock8s-\1(1)/' >> "${_MAN1_DIR}/${_MAIN_CMD}-${_CMD}-${_SUBCMD}.1"
    else
        printf '.SH NAME\n%s-%s-%s \\- %s %s %s command\n' "${_MAIN_CMD}" "${_CMD}" "${_SUBCMD}" "${_MAIN_CMD}" "${_CMD}" "${_SUBCMD}" >> "${_MAN1_DIR}/${_MAIN_CMD}-${_CMD}-${_SUBCMD}.1"
        printf '.SH SYNOPSIS\n       %s %s %s [options]\n\n.SH DESCRIPTION\n       %s %s %s command\n\n.SH SEE ALSO\n       %s-%s(1)\n' \
            "${_MAIN_CMD}" "${_CMD}" "${_SUBCMD}" "${_MAIN_CMD}" "${_CMD}" "${_SUBCMD}" "${_MAIN_CMD}" "${_CMD}" >> "${_MAN1_DIR}/${_MAIN_CMD}-${_CMD}-${_SUBCMD}.1"
    fi
}

generate_sub_sub_subcommand_manpage() {
    _CMD="$1"
    _SUBCMD="$2"
    _SUBSUBCMD="$3"
    _MAIN_CMD_UPPER=$(echo "${_MAIN_CMD}" | tr '[:lower:]' '[:upper:]') 2> /dev/null
    _CMD_UPPER=$(echo "${_CMD}" | tr '[:lower:]' '[:upper:]') 2> /dev/null
    _SUBCMD_UPPER=$(echo "${_SUBCMD}" | tr '[:lower:]' '[:upper:]') 2> /dev/null
    _SUBSUBCMD_UPPER=$(echo "${_SUBSUBCMD}" | tr '[:lower:]' '[:upper:]') 2> /dev/null
    printf '.TH %s-%s-%s-%s 1 "%s" "rock8s" "User Commands"\n' "${_MAIN_CMD_UPPER}" "${_CMD_UPPER}" "${_SUBCMD_UPPER}" "${_SUBSUBCMD_UPPER}" "$(date +'%B %Y')" > "${_MAN1_DIR}/${_MAIN_CMD}-${_CMD}-${_SUBCMD}-${_SUBSUBCMD}.1"
    _HELP_FILE="${_BUILD_DIR}/rock8s-help-${_CMD}-${_SUBCMD}-${_SUBSUBCMD}.txt"
    _SUBSUBCMD_FILE="libexec/${_CMD}/${_SUBCMD}/${_SUBSUBCMD}.sh"
    if [ -f "${_SUBSUBCMD_FILE}" ]; then
        extract_help_text "${_SUBSUBCMD_FILE}" "_help" "${_HELP_FILE}"
    fi
    if [ -s "${_HELP_FILE}" ]; then
        cat "${_HELP_FILE}" | \
            sed -e 's/^NAME$/.SH NAME/' | \
            sed -e 's/^SYNOPSIS$/.SH SYNOPSIS/' | \
            sed -e 's/^DESCRIPTION$/.SH DESCRIPTION/' | \
            sed -e 's/^ARGUMENTS$/.SH ARGUMENTS/' | \
            sed -e 's/^OPTIONS$/.SH OPTIONS/' | \
            sed -e 's/^COMMANDS$/.SH COMMANDS/' | \
            sed -e 's/^EXAMPLE$/.SH EXAMPLES/' | \
            sed -e 's/^SEE ALSO$/.SH SEE ALSO/' | \
            sed -e "s/rock8s ${_CMD} ${_SUBCMD} ${_SUBSUBCMD} \([a-z-]*\) --help/rock8s-${_CMD}-${_SUBCMD}-${_SUBSUBCMD}-\1(1)/" | \
            sed -e "s/rock8s ${_CMD} ${_SUBCMD} \([a-z-]*\) --help/rock8s-${_CMD}-${_SUBCMD}-\1(1)/" | \
            sed -e "s/rock8s ${_CMD} \([a-z-]*\) --help/rock8s-${_CMD}-\1(1)/" | \
            sed -e 's/rock8s \([a-z-]*\) --help/rock8s-\1(1)/' >> "${_MAN1_DIR}/${_MAIN_CMD}-${_CMD}-${_SUBCMD}-${_SUBSUBCMD}.1"
    else
        printf '.SH NAME\n%s-%s-%s-%s \\- %s %s %s %s command\n' "${_MAIN_CMD}" "${_CMD}" "${_SUBCMD}" "${_SUBSUBCMD}" "${_MAIN_CMD}" "${_CMD}" "${_SUBCMD}" "${_SUBSUBCMD}" >> "${_MAN1_DIR}/${_MAIN_CMD}-${_CMD}-${_SUBCMD}-${_SUBSUBCMD}.1"
        printf '.SH SYNOPSIS\n       %s %s %s %s [options]\n\n.SH DESCRIPTION\n       %s %s %s %s command\n\n.SH SEE ALSO\n       %s-%s-%s(1)\n' \
            "${_MAIN_CMD}" "${_CMD}" "${_SUBCMD}" "${_SUBSUBCMD}" "${_MAIN_CMD}" "${_CMD}" "${_SUBCMD}" "${_SUBSUBCMD}" "${_MAIN_CMD}" "${_CMD}" "${_SUBCMD}" >> "${_MAN1_DIR}/${_MAIN_CMD}-${_CMD}-${_SUBCMD}-${_SUBSUBCMD}.1"
    fi
}

rm -rf "${_MAN_DIR}" > /dev/null 2>&1
mkdir -p "${_MAN1_DIR}" > /dev/null 2>&1
generate_main_manpage
for _CMD in $_SUBCOMMANDS; do
    generate_subcommand_manpage "$_CMD"
done
for _SUBCMD in $_NODES_SUBCOMMANDS; do
    generate_sub_subcommand_manpage "nodes" "$_SUBCMD"
done
for _SUBCMD in $_CLUSTER_SUBCOMMANDS; do
    generate_sub_subcommand_manpage "cluster" "$_SUBCMD"
done
for _SUBCMD in $_PFSENSE_SUBCOMMANDS; do
    generate_sub_subcommand_manpage "pfsense" "$_SUBCMD"
done
for _SUBCMD in $_COMPLETION_SUBCOMMANDS; do
    generate_sub_subcommand_manpage "completion" "$_SUBCMD"
done
for _SUBSUBCMD in $_NODE_SUBCOMMANDS; do
    generate_sub_sub_subcommand_manpage "cluster" "node" "$_SUBSUBCMD"
done
