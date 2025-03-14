#!/bin/sh

set -e

export ROCK8S_LIB_PATH="$(pwd)"
_MAN_DIR="man"
_MAN1_DIR="${_MAN_DIR}/man1"
_BUILD_DIR=".build"
_MAIN_CMD="rock8s"
_SUBCOMMANDS="nodes cluster pfsense completion"
_NODES_SUBCMDS="ls create destroy ssh pubkey apply"
_CLUSTER_SUBCMDS="configure setup bootstrap login reset use apply install upgrade node scale"
_PFSENSE_SUBCMDS="configure list apply destroy publish"
_COMPLETION_SUBCMDS="bash zsh"

mkdir -p "${_MAN1_DIR}" > /dev/null 2>&1
mkdir -p "${_BUILD_DIR}" > /dev/null 2>&1

generate_main_manpage() {
    printf '.TH ROCK8S 1 "%s" "rock8s" "User Commands"\n' "$(date +'%B %Y')" > "${_MAN1_DIR}/${_MAIN_CMD}.1"
    printf '.SH NAME\n%s \\- universal kubernetes cluster\n' "${_MAIN_CMD}" >> "${_MAN1_DIR}/${_MAIN_CMD}.1"
    _HELP_FILE="${_BUILD_DIR}/rock8s-help-main.txt"
    ./rock8s.sh --help 2> "${_HELP_FILE}" > /dev/null || { 
        printf '.SH SYNOPSIS\n       %s [options]\n\n.SH DESCRIPTION\n       Universal kubernetes cluster\n' "${_MAIN_CMD}" >> "${_MAN1_DIR}/${_MAIN_CMD}.1"
        return 1; 
    }
    if [ -s "${_HELP_FILE}" ]; then
        sed -n -e '/^SYNOPSIS/,$p' "${_HELP_FILE}" > "${_HELP_FILE}-filtered" 2> /dev/null || true
        if [ -s "${_HELP_FILE}-filtered" ]; then
            cat "${_HELP_FILE}-filtered" | \
                sed -e 's/^SYNOPSIS$/.SH SYNOPSIS/' | \
                sed -e 's/^DESCRIPTION$/.SH DESCRIPTION/' | \
                sed -e 's/^OPTIONS$/.SH OPTIONS/' | \
                sed -e 's/^COMMANDS$/.SH COMMANDS/' | \
                sed -e 's/^EXAMPLE$/.SH EXAMPLES/' | \
                sed -e 's/^SEE ALSO$/.SH SEE ALSO/' | \
                sed -e 's/rock8s \([a-z-]*\) --help/rock8s-\1(1)/' >> "${_MAN1_DIR}/${_MAIN_CMD}.1" 2> /dev/null
        else
            printf '.SH SYNOPSIS\n       %s [options]\n\n.SH DESCRIPTION\n       Universal kubernetes cluster\n' "${_MAIN_CMD}" >> "${_MAN1_DIR}/${_MAIN_CMD}.1"
        fi
    else
        printf '.SH SYNOPSIS\n       %s [options]\n\n.SH DESCRIPTION\n       Universal kubernetes cluster\n' "${_MAIN_CMD}" >> "${_MAN1_DIR}/${_MAIN_CMD}.1"
    fi
    rm -f "${_HELP_FILE}" "${_HELP_FILE}-filtered" > /dev/null 2>&1
}

generate_subcommand_manpage() {
    _CMD="$1"
    _MAIN_CMD_UPPER=$(echo "${_MAIN_CMD}" | tr '[:lower:]' '[:upper:]') 2> /dev/null
    _CMD_UPPER=$(echo "${_CMD}" | tr '[:lower:]' '[:upper:]') 2> /dev/null
    printf '.TH %s-%s 1 "%s" "rock8s" "User Commands"\n' "${_MAIN_CMD_UPPER}" "${_CMD_UPPER}" "$(date +'%B %Y')" > "${_MAN1_DIR}/${_MAIN_CMD}-${_CMD}.1"
    printf '.SH NAME\n%s-%s \\- %s %s command\n' "${_MAIN_CMD}" "${_CMD}" "${_MAIN_CMD}" "${_CMD}" >> "${_MAN1_DIR}/${_MAIN_CMD}-${_CMD}.1"
    _HELP_FILE="${_BUILD_DIR}/rock8s-help-${_CMD}.txt"
    ./rock8s.sh "${_CMD}" --help 2> "${_HELP_FILE}" > /dev/null || { 
        printf '.SH SYNOPSIS\n       %s %s [options]\n\n.SH DESCRIPTION\n       %s command\n\n.SH SEE ALSO\n       %s(1)\n' \
            "${_MAIN_CMD}" "${_CMD}" "${_CMD}" "${_MAIN_CMD}" >> "${_MAN1_DIR}/${_MAIN_CMD}-${_CMD}.1"
        return 0; 
    }
    if [ -s "${_HELP_FILE}" ]; then
        sed -n -e '/^SYNOPSIS/,$p' "${_HELP_FILE}" > "${_HELP_FILE}-filtered" 2> /dev/null || true
        if [ -s "${_HELP_FILE}-filtered" ]; then
            cat "${_HELP_FILE}-filtered" | \
                sed -e 's/^SYNOPSIS$/.SH SYNOPSIS/' | \
                sed -e 's/^DESCRIPTION$/.SH DESCRIPTION/' | \
                sed -e 's/^OPTIONS$/.SH OPTIONS/' | \
                sed -e 's/^COMMANDS$/.SH COMMANDS/' | \
                sed -e 's/^EXAMPLE$/.SH EXAMPLES/' | \
                sed -e 's/^SEE ALSO$/.SH SEE ALSO/' | \
                sed -e 's/rock8s \([a-z-]*\) --help/rock8s-\1(1)/' | \
                sed -e "s/rock8s ${_CMD} \([a-z-]*\) --help/rock8s-${_CMD}-\1(1)/" >> "${_MAN1_DIR}/${_MAIN_CMD}-${_CMD}.1" 2> /dev/null
        else
            printf '.SH SYNOPSIS\n       %s %s [options]\n\n.SH DESCRIPTION\n       %s command\n\n.SH SEE ALSO\n       %s(1)\n' \
                "${_MAIN_CMD}" "${_CMD}" "${_CMD}" "${_MAIN_CMD}" >> "${_MAN1_DIR}/${_MAIN_CMD}-${_CMD}.1"
        fi
    else
        printf '.SH SYNOPSIS\n       %s %s [options]\n\n.SH DESCRIPTION\n       %s command\n\n.SH SEE ALSO\n       %s(1)\n' \
            "${_MAIN_CMD}" "${_CMD}" "${_CMD}" "${_MAIN_CMD}" >> "${_MAN1_DIR}/${_MAIN_CMD}-${_CMD}.1"
    fi
    rm -f "${_HELP_FILE}" "${_HELP_FILE}-filtered" > /dev/null 2>&1
    return 0
}

generate_sub_subcommand_manpage() {
    _CMD="$1"
    _SUBCMD="$2"
    _MAIN_CMD_UPPER=$(echo "${_MAIN_CMD}" | tr '[:lower:]' '[:upper:]') 2> /dev/null
    _CMD_UPPER=$(echo "${_CMD}" | tr '[:lower:]' '[:upper:]') 2> /dev/null
    _SUBCMD_UPPER=$(echo "${_SUBCMD}" | tr '[:lower:]' '[:upper:]') 2> /dev/null
    printf '.TH %s-%s-%s 1 "%s" "rock8s" "User Commands"\n' "${_MAIN_CMD_UPPER}" "${_CMD_UPPER}" "${_SUBCMD_UPPER}" "$(date +'%B %Y')" > "${_MAN1_DIR}/${_MAIN_CMD}-${_CMD}-${_SUBCMD}.1"
    printf '.SH NAME\n%s-%s-%s \\- %s %s %s command\n' "${_MAIN_CMD}" "${_CMD}" "${_SUBCMD}" "${_MAIN_CMD}" "${_CMD}" "${_SUBCMD}" >> "${_MAN1_DIR}/${_MAIN_CMD}-${_CMD}-${_SUBCMD}.1"
    _HELP_FILE="${_BUILD_DIR}/rock8s-help-${_CMD}-${_SUBCMD}.txt"
    ./rock8s.sh "${_CMD}" "${_SUBCMD}" --help 2> "${_HELP_FILE}" > /dev/null || {
        printf '.SH SYNOPSIS\n       %s %s %s [options]\n\n.SH DESCRIPTION\n       %s %s %s command\n\n.SH SEE ALSO\n       %s-%s(1)\n' \
            "${_MAIN_CMD}" "${_CMD}" "${_SUBCMD}" "${_MAIN_CMD}" "${_CMD}" "${_SUBCMD}" "${_MAIN_CMD}" "${_CMD}" >> "${_MAN1_DIR}/${_MAIN_CMD}-${_CMD}-${_SUBCMD}.1"
        return 0;
    }
    if [ -s "${_HELP_FILE}" ]; then
        sed -n -e '/^SYNOPSIS/,$p' "${_HELP_FILE}" > "${_HELP_FILE}-filtered" 2> /dev/null || true
        if [ -s "${_HELP_FILE}-filtered" ]; then
            cat "${_HELP_FILE}-filtered" | \
                sed -e 's/^SYNOPSIS$/.SH SYNOPSIS/' | \
                sed -e 's/^DESCRIPTION$/.SH DESCRIPTION/' | \
                sed -e 's/^OPTIONS$/.SH OPTIONS/' | \
                sed -e 's/^COMMANDS$/.SH COMMANDS/' | \
                sed -e 's/^EXAMPLE$/.SH EXAMPLES/' | \
                sed -e 's/^SEE ALSO$/.SH SEE ALSO/' | \
                sed -e "s/rock8s ${_CMD} ${_SUBCMD} \([a-z-]*\) --help/rock8s-${_CMD}-${_SUBCMD}-\1(1)/" | \
                sed -e "s/rock8s ${_CMD} \([a-z-]*\) --help/rock8s-${_CMD}-\1(1)/" | \
                sed -e 's/rock8s \([a-z-]*\) --help/rock8s-\1(1)/' >> "${_MAN1_DIR}/${_MAIN_CMD}-${_CMD}-${_SUBCMD}.1" 2> /dev/null
        else
            printf '.SH SYNOPSIS\n       %s %s %s [options]\n\n.SH DESCRIPTION\n       %s %s %s command\n\n.SH SEE ALSO\n       %s-%s(1)\n' \
                "${_MAIN_CMD}" "${_CMD}" "${_SUBCMD}" "${_MAIN_CMD}" "${_CMD}" "${_SUBCMD}" "${_MAIN_CMD}" "${_CMD}" >> "${_MAN1_DIR}/${_MAIN_CMD}-${_CMD}-${_SUBCMD}.1"
        fi
    else
        printf '.SH SYNOPSIS\n       %s %s %s [options]\n\n.SH DESCRIPTION\n       %s %s %s command\n\n.SH SEE ALSO\n       %s-%s(1)\n' \
            "${_MAIN_CMD}" "${_CMD}" "${_SUBCMD}" "${_MAIN_CMD}" "${_CMD}" "${_SUBCMD}" "${_MAIN_CMD}" "${_CMD}" >> "${_MAN1_DIR}/${_MAIN_CMD}-${_CMD}-${_SUBCMD}.1"
    fi
    rm -f "${_HELP_FILE}" "${_HELP_FILE}-filtered" > /dev/null 2>&1
    return 0
}
rm -rf "${_MAN_DIR}" > /dev/null 2>&1
mkdir -p "${_MAN1_DIR}" > /dev/null 2>&1

{
    generate_main_manpage || true
    for _CMD in ${_SUBCOMMANDS}; do
        generate_subcommand_manpage "${_CMD}" || true
    done
    for _SUBCMD in ${_NODES_SUBCMDS}; do
        generate_sub_subcommand_manpage "nodes" "${_SUBCMD}" || true
    done
    for _SUBCMD in ${_CLUSTER_SUBCMDS}; do
        generate_sub_subcommand_manpage "cluster" "${_SUBCMD}" || true
    done
    for _SUBCMD in ${_PFSENSE_SUBCMDS}; do
        generate_sub_subcommand_manpage "pfsense" "${_SUBCMD}" || true
    done
    for _SUBCMD in ${_COMPLETION_SUBCMDS}; do
        generate_sub_subcommand_manpage "completion" "${_SUBCMD}" || true
    done
} > /dev/null
