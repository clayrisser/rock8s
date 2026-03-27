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
    file="$1"
    func_name="$2"
    output_file="$3"
    if [ -f "${file}" ]; then
        sed -n "/${func_name}() {/,/^}/p" "${file}" |
            sed -n '/cat <<EOF/,/EOF/p' |
            sed '1d;$d' > "${output_file}"
        return 0
    else
        return 1
    fi
}

generate_main_manpage() {
    printf '.TH ROCK8S 1 "%s" "rock8s" "User Commands"\n' "$(date +'%B %Y')" > "${_MAN1_DIR}/${_MAIN_CMD}.1"
    help_file="${_BUILD_DIR}/rock8s-help-main.txt"
    extract_help_text "rock8s.sh" "_help" "${help_file}"
    if [ -s "${help_file}" ]; then
        cat "${help_file}" | \
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
    cmd="$1"
    main_cmd_upper=$(echo "${_MAIN_CMD}" | tr '[:lower:]' '[:upper:]') 2> /dev/null
    cmd_upper=$(echo "${cmd}" | tr '[:lower:]' '[:upper:]') 2> /dev/null
    printf '.TH %s-%s 1 "%s" "rock8s" "User Commands"\n' "${main_cmd_upper}" "${cmd_upper}" "$(date +'%B %Y')" > "${_MAN1_DIR}/${_MAIN_CMD}-${cmd}.1"
    help_file="${_BUILD_DIR}/rock8s-help-${cmd}.txt"
    subcmd_file="libexec/${cmd}.sh"
    if [ -f "${subcmd_file}" ]; then
        extract_help_text "${subcmd_file}" "_help" "${help_file}"
    fi
    if [ -s "${help_file}" ]; then
        cat "${help_file}" | \
            sed -e 's/^NAME$/.SH NAME/' | \
            sed -e 's/^SYNOPSIS$/.SH SYNOPSIS/' | \
            sed -e 's/^DESCRIPTION$/.SH DESCRIPTION/' | \
            sed -e 's/^OPTIONS$/.SH OPTIONS/' | \
            sed -e 's/^COMMANDS$/.SH COMMANDS/' | \
            sed -e 's/^EXAMPLE$/.SH EXAMPLES/' | \
            sed -e 's/^SEE ALSO$/.SH SEE ALSO/' | \
            sed -e 's/rock8s \([a-z-]*\) --help/rock8s-\1(1)/' | \
            sed -e "s/rock8s ${cmd} \([a-z-]*\) --help/rock8s-${cmd}-\1(1)/" >> "${_MAN1_DIR}/${_MAIN_CMD}-${cmd}.1"
    else
        printf '.SH NAME\n%s-%s \\- %s %s command\n' "${_MAIN_CMD}" "${cmd}" "${_MAIN_CMD}" "${cmd}" >> "${_MAN1_DIR}/${_MAIN_CMD}-${cmd}.1"
        printf '.SH SYNOPSIS\n       %s %s [options]\n\n.SH DESCRIPTION\n       %s command\n\n.SH SEE ALSO\n       %s(1)\n' \
            "${_MAIN_CMD}" "${cmd}" "${cmd}" "${_MAIN_CMD}" >> "${_MAN1_DIR}/${_MAIN_CMD}-${cmd}.1"
    fi
}

generate_sub_subcommand_manpage() {
    cmd="$1"
    subcmd="$2"
    main_cmd_upper=$(echo "${_MAIN_CMD}" | tr '[:lower:]' '[:upper:]') 2> /dev/null
    cmd_upper=$(echo "${cmd}" | tr '[:lower:]' '[:upper:]') 2> /dev/null
    subcmd_upper=$(echo "${subcmd}" | tr '[:lower:]' '[:upper:]') 2> /dev/null
    printf '.TH %s-%s-%s 1 "%s" "rock8s" "User Commands"\n' "${main_cmd_upper}" "${cmd_upper}" "${subcmd_upper}" "$(date +'%B %Y')" > "${_MAN1_DIR}/${_MAIN_CMD}-${cmd}-${subcmd}.1"
    help_file="${_BUILD_DIR}/rock8s-help-${cmd}-${subcmd}.txt"
    subcmd_file="libexec/${cmd}/${subcmd}.sh"
    if [ -f "${subcmd_file}" ]; then
        extract_help_text "${subcmd_file}" "_help" "${help_file}"
    fi
    if [ -s "${help_file}" ]; then
        cat "${help_file}" | \
            sed -e 's/^NAME$/.SH NAME/' | \
            sed -e 's/^SYNOPSIS$/.SH SYNOPSIS/' | \
            sed -e 's/^DESCRIPTION$/.SH DESCRIPTION/' | \
            sed -e 's/^OPTIONS$/.SH OPTIONS/' | \
            sed -e 's/^COMMANDS$/.SH COMMANDS/' | \
            sed -e 's/^EXAMPLE$/.SH EXAMPLES/' | \
            sed -e 's/^SEE ALSO$/.SH SEE ALSO/' | \
            sed -e "s/rock8s ${cmd} ${subcmd} \([a-z-]*\) --help/rock8s-${cmd}-${subcmd}-\1(1)/" | \
            sed -e "s/rock8s ${cmd} \([a-z-]*\) --help/rock8s-${cmd}-\1(1)/" | \
            sed -e 's/rock8s \([a-z-]*\) --help/rock8s-\1(1)/' >> "${_MAN1_DIR}/${_MAIN_CMD}-${cmd}-${subcmd}.1"
    else
        printf '.SH NAME\n%s-%s-%s \\- %s %s %s command\n' "${_MAIN_CMD}" "${cmd}" "${subcmd}" "${_MAIN_CMD}" "${cmd}" "${subcmd}" >> "${_MAN1_DIR}/${_MAIN_CMD}-${cmd}-${subcmd}.1"
        printf '.SH SYNOPSIS\n       %s %s %s [options]\n\n.SH DESCRIPTION\n       %s %s %s command\n\n.SH SEE ALSO\n       %s-%s(1)\n' \
            "${_MAIN_CMD}" "${cmd}" "${subcmd}" "${_MAIN_CMD}" "${cmd}" "${subcmd}" "${_MAIN_CMD}" "${cmd}" >> "${_MAN1_DIR}/${_MAIN_CMD}-${cmd}-${subcmd}.1"
    fi
}

generate_sub_sub_subcommand_manpage() {
    cmd="$1"
    subcmd="$2"
    subsubcmd="$3"
    main_cmd_upper=$(echo "${_MAIN_CMD}" | tr '[:lower:]' '[:upper:]') 2> /dev/null
    cmd_upper=$(echo "${cmd}" | tr '[:lower:]' '[:upper:]') 2> /dev/null
    subcmd_upper=$(echo "${subcmd}" | tr '[:lower:]' '[:upper:]') 2> /dev/null
    subsubcmd_upper=$(echo "${subsubcmd}" | tr '[:lower:]' '[:upper:]') 2> /dev/null
    printf '.TH %s-%s-%s-%s 1 "%s" "rock8s" "User Commands"\n' "${main_cmd_upper}" "${cmd_upper}" "${subcmd_upper}" "${subsubcmd_upper}" "$(date +'%B %Y')" > "${_MAN1_DIR}/${_MAIN_CMD}-${cmd}-${subcmd}-${subsubcmd}.1"
    help_file="${_BUILD_DIR}/rock8s-help-${cmd}-${subcmd}-${subsubcmd}.txt"
    subsubcmd_file="libexec/${cmd}/${subcmd}/${subsubcmd}.sh"
    if [ -f "${subsubcmd_file}" ]; then
        extract_help_text "${subsubcmd_file}" "_help" "${help_file}"
    fi
    if [ -s "${help_file}" ]; then
        cat "${help_file}" | \
            sed -e 's/^NAME$/.SH NAME/' | \
            sed -e 's/^SYNOPSIS$/.SH SYNOPSIS/' | \
            sed -e 's/^DESCRIPTION$/.SH DESCRIPTION/' | \
            sed -e 's/^ARGUMENTS$/.SH ARGUMENTS/' | \
            sed -e 's/^OPTIONS$/.SH OPTIONS/' | \
            sed -e 's/^COMMANDS$/.SH COMMANDS/' | \
            sed -e 's/^EXAMPLE$/.SH EXAMPLES/' | \
            sed -e 's/^SEE ALSO$/.SH SEE ALSO/' | \
            sed -e "s/rock8s ${cmd} ${subcmd} ${subsubcmd} \([a-z-]*\) --help/rock8s-${cmd}-${subcmd}-${subsubcmd}-\1(1)/" | \
            sed -e "s/rock8s ${cmd} ${subcmd} \([a-z-]*\) --help/rock8s-${cmd}-${subcmd}-\1(1)/" | \
            sed -e "s/rock8s ${cmd} \([a-z-]*\) --help/rock8s-${cmd}-\1(1)/" | \
            sed -e 's/rock8s \([a-z-]*\) --help/rock8s-\1(1)/' >> "${_MAN1_DIR}/${_MAIN_CMD}-${cmd}-${subcmd}-${subsubcmd}.1"
    else
        printf '.SH NAME\n%s-%s-%s-%s \\- %s %s %s %s command\n' "${_MAIN_CMD}" "${cmd}" "${subcmd}" "${subsubcmd}" "${_MAIN_CMD}" "${cmd}" "${subcmd}" "${subsubcmd}" >> "${_MAN1_DIR}/${_MAIN_CMD}-${cmd}-${subcmd}-${subsubcmd}.1"
        printf '.SH SYNOPSIS\n       %s %s %s %s [options]\n\n.SH DESCRIPTION\n       %s %s %s %s command\n\n.SH SEE ALSO\n       %s-%s-%s(1)\n' \
            "${_MAIN_CMD}" "${cmd}" "${subcmd}" "${subsubcmd}" "${_MAIN_CMD}" "${cmd}" "${subcmd}" "${subsubcmd}" "${_MAIN_CMD}" "${cmd}" "${subcmd}" >> "${_MAN1_DIR}/${_MAIN_CMD}-${cmd}-${subcmd}-${subsubcmd}.1"
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
