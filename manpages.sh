#!/bin/sh

set -e

_MAN_DIR="man"
_MAN1_DIR="${_MAN_DIR}/man1"
_BUILD_DIR=".build"
_MAIN_CMD="rock8s"
_SUBCOMMANDS="init nodes cluster completion"
_NODES_SUBCOMMANDS="apply destroy ls pubkey ssh"
_CLUSTER_SUBCOMMANDS="addons apply install login node reset rotate-certs scale upgrade"
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
            sed '1d;$d' >"${output_file}"
        return 0
    else
        return 1
    fi
}

generate_main_manpage() {
    printf '.TH ROCK8S 1 "%s" "rock8s" "User Commands"\n' "$(date +'%B %Y')" >"${_MAN1_DIR}/${_MAIN_CMD}.1"
    help_file="${_BUILD_DIR}/rock8s-help-main.txt"
    extract_help_text "rock8s.sh" "_help" "${help_file}"
    if [ -s "${help_file}" ]; then
        sed -e 's/^NAME$/.SH NAME/' \
            -e 's/^SYNOPSIS$/.SH SYNOPSIS/' \
            -e 's/^DESCRIPTION$/.SH DESCRIPTION/' \
            -e 's/^OPTIONS$/.SH OPTIONS/' \
            -e 's/^COMMANDS$/.SH COMMANDS/' \
            -e 's/^EXAMPLE$/.SH EXAMPLES/' \
            -e 's/^SEE ALSO$/.SH SEE ALSO/' \
            -e 's/rock8s \([a-z-]*\) --help/rock8s-\1(1)/' \
            <"${help_file}" >>"${_MAN1_DIR}/${_MAIN_CMD}.1"
    else
        printf '.SH NAME\n%s \\- universal kubernetes cluster\n' "${_MAIN_CMD}" >>"${_MAN1_DIR}/${_MAIN_CMD}.1"
        printf '.SH SYNOPSIS\n       %s [options]\n\n.SH DESCRIPTION\n       Universal kubernetes cluster\n' "${_MAIN_CMD}" >>"${_MAN1_DIR}/${_MAIN_CMD}.1"
    fi
}

generate_manpage() {
    man_name="${_MAIN_CMD}"
    th_header="$(echo "${_MAIN_CMD}" | tr '[:lower:]' '[:upper:]')"
    src_path="libexec"
    desc="${_MAIN_CMD}"
    depth=$#
    args=""
    for part in "$@"; do
        part_upper=$(echo "${part}" | tr '[:lower:]' '[:upper:]') 2>/dev/null
        man_name="${man_name}-${part}"
        th_header="${th_header}-${part_upper}"
        src_path="${src_path}/${part}"
        desc="${desc} ${part}"
        args="${args:+$args }$part"
    done

    output_file="${_MAN1_DIR}/${man_name}.1"
    src_file="${src_path}.sh"
    help_file="${_BUILD_DIR}/${man_name}-help.txt"

    printf '.TH %s 1 "%s" "rock8s" "User Commands"\n' "$th_header" "$(date +'%B %Y')" >"$output_file"

    if [ -f "$src_file" ]; then
        extract_help_text "$src_file" "_help" "$help_file"
    fi

    if [ -s "$help_file" ]; then
        sed_file=$(mktemp)
        cat >"$sed_file" <<'SEDEOF'
s/^NAME$/.SH NAME/
s/^SYNOPSIS$/.SH SYNOPSIS/
s/^DESCRIPTION$/.SH DESCRIPTION/
s/^ARGUMENTS$/.SH ARGUMENTS/
s/^OPTIONS$/.SH OPTIONS/
s/^COMMANDS$/.SH COMMANDS/
s/^EXAMPLE$/.SH EXAMPLES/
s/^SEE ALSO$/.SH SEE ALSO/
SEDEOF
        n=$depth
        while [ $n -gt 0 ]; do
            prefix_pattern="rock8s"
            prefix_replacement="rock8s"
            count=0
            for part in $args; do
                count=$((count + 1))
                [ $count -gt $n ] && break
                prefix_pattern="$prefix_pattern $part"
                prefix_replacement="$prefix_replacement-$part"
            done
            printf 's/%s \\([a-z-]*\\) --help/%s-\\1(1)/\n' "$prefix_pattern" "$prefix_replacement" >>"$sed_file"
            n=$((n - 1))
        done
        printf 's/rock8s \\([a-z-]*\\) --help/rock8s-\\1(1)/\n' >>"$sed_file"
        sed -f "$sed_file" <"$help_file" >>"$output_file"
        rm -f "$sed_file"
    else
        parent_name="${man_name%-*}"
        printf '.SH NAME\n%s \\- %s command\n' "$man_name" "$desc" >>"$output_file"
        printf '.SH SYNOPSIS\n       %s [options]\n\n.SH DESCRIPTION\n       %s command\n\n.SH SEE ALSO\n       %s(1)\n' \
            "$desc" "$desc" "$parent_name" >>"$output_file"
    fi
}

rm -rf "${_MAN_DIR}" >/dev/null 2>&1
mkdir -p "${_MAN1_DIR}" >/dev/null 2>&1
generate_main_manpage
for _CMD in $_SUBCOMMANDS; do
    generate_manpage "$_CMD"
done
for _SUBCMD in $_NODES_SUBCOMMANDS; do
    generate_manpage "nodes" "$_SUBCMD"
done
for _SUBCMD in $_CLUSTER_SUBCOMMANDS; do
    generate_manpage "cluster" "$_SUBCMD"
done
for _SUBCMD in $_COMPLETION_SUBCOMMANDS; do
    generate_manpage "completion" "$_SUBCMD"
done
for _SUBSUBCMD in $_NODE_SUBCOMMANDS; do
    generate_manpage "cluster" "node" "$_SUBSUBCMD"
done
